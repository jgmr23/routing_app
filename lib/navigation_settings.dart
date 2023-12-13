// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/navigation.dart';
import 'package:here_sdk/prefetcher.dart';
import 'package:here_sdk/routing.dart';
import 'installation_point_model.dart';
import 'positioning_provider.dart';

enum TtsState { playing, stopped, paused, continued }

class NavigationSettings {
  MapPolyline? calculatedRouteMapPolyline;
  final HereMapController _hereMapController;
  late VisualNavigator _visualNavigator;
  HEREPositioningProvider _herePositioningProvider;
  MapMatchedLocation? _lastMapMatchedLocation;
  int _previousManeuverIndex = -1;
  RoutePrefetcher _routePrefetcher;
  bool canCalculate = true;
  List<MapMarker> _mapMarkerList = [];
  TtsState ttsState = TtsState.stopped;

  final instance = NavigationSettings;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;

  get isPaused => ttsState == TtsState.paused;

  get isContinued => ttsState == TtsState.continued;

  double heightButton = 60;
  double fontSize = 18;
  double iconSize = 30;
  double speed = 0;

  NavigationSettings(
    HereMapController hereMapController,
  )   : _hereMapController = hereMapController,
        _herePositioningProvider = HEREPositioningProvider(),
        _routePrefetcher = RoutePrefetcher(SDKNativeEngine.sharedInstance!) {
    try {
      _visualNavigator = VisualNavigator();
    } on InstantiationException {
      throw Exception("Initialization of VisualNavigator failed.");
    }
    _hereMapController.mapScene.enableFeatures(
      {MapFeatures.vehicleRestrictions: MapFeatureModes.defaultMode, MapFeatures.buildingFootprints: MapFeatureModes.defaultMode},
    );

    _hereMapController.mapScene.disableFeatures([MapFeatures.extrudedBuildings]);

    double distanceToEarthInMeters = 1000 * 750.0;
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    var tilt = 0.0;
    var newOrientation = GeoOrientationUpdate(null, tilt);
    _hereMapController.camera.lookAtPointWithGeoOrientationAndMeasure(GeoCoordinates(39.694817, -8.138151), newOrientation, mapMeasureZoom);

    _visualNavigator.cameraBehavior = DynamicCameraBehavior();
    _setTapGestureHandler();

    _visualNavigator.startRendering(_hereMapController);

    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);

    setupListeners();
  }

  void myLocation() {
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  void changeCamera() {
    var tilt = 0.0;
    var newOrientation = GeoOrientationUpdate(null, tilt);
    _hereMapController.camera.setOrientationAtTarget(newOrientation);
  }

  void prefetchMapData(GeoCoordinates currentGeoCoordinates) {
    _routePrefetcher.prefetchAroundLocation(currentGeoCoordinates);
    _routePrefetcher.prefetchAroundRouteOnIntervals(_visualNavigator);
  }

  void _setTapGestureHandler() {
    _hereMapController.gestures.tapListener = TapListener((Point2D touchPoint) {
      _pickMapMarker(touchPoint);
    });
    _hereMapController.gestures.doubleTapListener = DoubleTapListener((origin) => enableTracking(false));
    _hereMapController.gestures.panListener = PanListener((state, origin, translation, velocity) => enableTracking(false));
    _hereMapController.gestures.pinchRotateListener = PinchRotateListener((state, pinchOrigin, rotationOrigin, twoFingerDistance, rotation) => enableTracking(false));
    _hereMapController.gestures.twoFingerPanListener = TwoFingerPanListener((state, origin, translation, velocity) => enableTracking(false));
    _hereMapController.gestures.twoFingerTapListener = TwoFingerTapListener((origin) => enableTracking(false));
  }

  void enableTracking(bool enable) {
    _visualNavigator.cameraBehavior = enable ? DynamicCameraBehavior() : null;
  }

  bool getCameraBehavior() {
    return _visualNavigator.cameraBehavior != null ? true : false;
  }

  void _pickMapMarker(Point2D touchPoint) {
    double radiusInPixel = 2;
    _hereMapController.pickMapItems(touchPoint, radiusInPixel, (pickMapItemsResult) {
      if (pickMapItemsResult == null) {
        // Pick operation failed.
        return;
      }
      List<MapMarker> mapMarkerList = pickMapItemsResult.markers;
      if (mapMarkerList.length == 0) {
        print("No map markers found.");
        return;
      }

      MapMarker topmostMapMarker = mapMarkerList.first;
      Metadata? metadata = topmostMapMarker.metadata;
      if (metadata != null) {
        String message = metadata.getString("key_poi") ?? "No message found.";

        final decode = jsonDecode(message);

        return;
      }
    });
  }

  Future<void> addPOIMapMarker(GeoCoordinates geoCoordinates, Uint8List imagePixelData, InstallationPoints ip) async {
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);
    MapMarker mapMarker = MapMarker.withAnchor(geoCoordinates, MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png), anchor2D);

    Metadata metadata = Metadata();
    metadata.setString("key_poi", jsonEncode(ip));
    mapMarker.metadata = metadata;

    _mapMarkerList.add(mapMarker);
    _hereMapController.mapScene.addMapMarker(mapMarker);
  }

  Future<void> addGeofenceMarker(GeoCoordinates geoCoordinates, Uint8List imagePixelData) async {
    Anchor2D anchor2D = Anchor2D.withHorizontalAndVertical(0.5, 1);
    MapMarker mapMarker = MapMarker.withAnchor(geoCoordinates, MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png), anchor2D);
    _mapMarkerList.add(mapMarker);
    _hereMapController.mapScene.addMapMarker(mapMarker);
  }

  Future<void> removeAllMapMarker() async {
    _hereMapController.mapScene.removeMapMarkers(_mapMarkerList);
    _mapMarkerList.clear();
  }

  static Future<Uint8List> loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }

  Location? getLastKnownLocation() {
    return _herePositioningProvider.getLastKnownLocation();
  }

  void startNavigation(Route route) {
    GeoCoordinates startGeoCoordinates = route.geometry.vertices[0];
    prefetchMapData(startGeoCoordinates);

    _prepareNavigation(route);

    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  void startGeofenceNavigation(Route route) {
    GeoCoordinates startGeoCoordinates = route.geometry.vertices[0];
    prefetchMapData(startGeoCoordinates);
    _prepareNavigation(route);
    log("Start Navigation");
  }

  void _prepareNavigation(Route route) {
    _setupSpeedWarnings();
    setupVoiceTextMessages();
    _setupRealisticViewWarnings();

    // Set the route to follow.
    _visualNavigator.route = route;
  }

  void stopNavigation() {
    _routePrefetcher.stopPrefetchAroundRoute();
    startTracking();
    //log("Tracking device's location.");
  }

  void detach() {
    _visualNavigator.stopRendering();
    _herePositioningProvider.stop();
  }

  void startTracking() {
    _visualNavigator.route = null;
    _herePositioningProvider.startLocating(_visualNavigator, LocationAccuracy.navigation);
  }

  Future _speak(String text) async {
    print(text);
  }

  void setupListeners() {
    // Notifies on the progress along the route including maneuver instructions.
    // These maneuver instructions can be used to compose a visual representation of the next maneuver actions.
    _visualNavigator.routeProgressListener = RouteProgressListener((RouteProgress routeProgress) {
      // Handle results from onRouteProgressUpdated():
      List<SectionProgress> sectionProgressList = routeProgress.sectionProgress;
      // sectionProgressList is guaranteed to be non-empty.
      SectionProgress lastSectionProgress = sectionProgressList.elementAt(sectionProgressList.length - 1);
      print('Distance to destination in meters: ' + lastSectionProgress.remainingDistanceInMeters.toString());
      //print('Traffic delay ahead in seconds: ' + lastSectionProgress.trafficDelay.inSeconds.toString());

      log("Distance to waypoint: " + routeProgress.sectionProgress[routeProgress.sectionIndex].remainingDistanceInMeters.toString());

      // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
      List<ManeuverProgress> nextManeuverList = routeProgress.maneuverProgress;

      if (nextManeuverList.isEmpty) {
        print('No next maneuver available.');
        return;
      }
      ManeuverProgress nextManeuverProgress = nextManeuverList.first;

      int nextManeuverIndex = nextManeuverProgress.maneuverIndex;
      Maneuver? nextManeuver = _visualNavigator.getManeuver(nextManeuverIndex);
      if (nextManeuver == null) {
        // Should never happen as we retrieved the next maneuver progress above.
        return;
      }

      ManeuverAction action = nextManeuver.action;
      //String roadName = _getRoadName(nextManeuver);
      //String logMessage = describeEnum(action) + ' on ' + roadName + ' in ' + nextManeuverProgress.remainingDistanceInMeters.toString() + ' meters.';

      //log("Actions: $logMessage");
      //log("Action detail: " + action.name);

      //updateDistanceState(nextManeuverProgress.remainingDistanceInMeters.toString());

      if (_previousManeuverIndex != nextManeuverIndex) {

      } else {
        // A maneuver update contains a different distance to reach the next maneuver.
      }

      _previousManeuverIndex = nextManeuverIndex;

      if (_lastMapMatchedLocation != null) {
        // Update the route based on the current location of the driver.
        // We periodically want to search for better traffic-optimized routes.
      }
    });

    // Notifies on the current map-matched location and other useful information while driving or walking.
    // The map-matched location is used to update the map view.
    _visualNavigator.navigableLocationListener = NavigableLocationListener((NavigableLocation currentNavigableLocation) {
      // Handle results from onNavigableLocationUpdated():
      MapMatchedLocation? mapMatchedLocation = currentNavigableLocation.mapMatchedLocation;
      if (mapMatchedLocation == null) {
        //print("This new location could not be map-matched. Are you off-road?");
        return;
      }

      _lastMapMatchedLocation = mapMatchedLocation;

      speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond ?? 0;

      var accuracy = currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond;
      //print("Driving speed (m/s): $speed plus/minus an accuracy of: $accuracy");
    });

    // Notifies when the destination of the route is reached.
    _visualNavigator.destinationReachedListener = DestinationReachedListener(() {
      // Handle results from onDestinationReached().
      //log("Destination reached. Stopping turn-by-turn navigation.");
      stopNavigation();
    });

    // Notifies when a waypoint on the route is reached or missed
    _visualNavigator.milestoneStatusListener = MilestoneStatusListener((Milestone milestone, MilestoneStatus milestoneStatus) {
      // Handle results from onMilestoneStatusUpdated().
      if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.reached) {
        //print("A user-defined waypoint was reached, index of waypoint: " + milestone.waypointIndex.toString());
        log("Chegou ao Destino");
      } else if (milestone.waypointIndex != null && milestoneStatus == MilestoneStatus.missed) {
        print("A user-defined waypoint was missed, index of waypoint: " + milestone.waypointIndex.toString());
        print("Original coordinates: " + milestone.originalCoordinates.toString());
      } else if (milestone.waypointIndex == null && milestoneStatus == MilestoneStatus.reached) {
        // For example, when transport mode changes due to a ferry a system-defined waypoint may have been added.
        print("A system-defined waypoint was reached at: " + milestone.mapMatchedCoordinates.toString());
      }
    });

    // Notifies on a possible deviation from the route.
    // When deviation is too large, an app may decide to recalculate the route from current location to destination.
    _visualNavigator.routeDeviationListener = RouteDeviationListener((RouteDeviation routeDeviation) {});

    // Notifies on voice maneuver messages.
    _visualNavigator.maneuverNotificationListener = ManeuverNotificationListener((String voiceText) {
      // Handle results lambda_onManeuverNotification().
      // Flutter itself does not provide a text-to-speech engine. Use one of the available TTS plugins to speak
      // the voiceText message.
      //print("Voice guidance text: $voiceText");
      //log('->: $voiceText');

      _speak(voiceText);
    });
  }

  void _setupSpeedWarnings() {
    SpeedLimitOffset speedLimitOffset = SpeedLimitOffset();
    speedLimitOffset.lowSpeedOffsetInMetersPerSecond = 2;
    speedLimitOffset.highSpeedOffsetInMetersPerSecond = 4;
    speedLimitOffset.highSpeedBoundaryInMetersPerSecond = 25;

    _visualNavigator.speedWarningOptions = SpeedWarningOptions(speedLimitOffset);
  }

  void setupVoiceTextMessages() {
    LanguageCode languageCode = LanguageCode.ptPt;
    List<LanguageCode> supportedVoiceSkins = VisualNavigator.getAvailableLanguagesForManeuverNotifications();
    if (supportedVoiceSkins.contains(languageCode)) {
      _visualNavigator.maneuverNotificationOptions = ManeuverNotificationOptions(languageCode, UnitSystem.metric);
    } else {
      print('Warning: Requested voice skin is not supported.');
    }
  }

  void _setupRealisticViewWarnings() {
    RealisticViewWarningOptions realisticViewWarningOptions = RealisticViewWarningOptions();
    realisticViewWarningOptions.aspectRatio = AspectRatio.aspectRatio3X4;
    realisticViewWarningOptions.darkTheme = false;
    _visualNavigator.realisticViewWarningOptions = realisticViewWarningOptions;
  }
}
