/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import 'dart:developer';
import 'dart:typed_data';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:routing_app/installation_point_model.dart';
import 'package:routing_app/ip_data.dart';
import 'package:routing_app/route_calculator.dart';
import 'navigation_settings.dart';
import 'package:here_sdk/routing.dart';

class RoutingExample {
  final HereMapController hereMapController;
  final NavigationSettings navigationSettings;
  final RouteCalculator routeCalculator;
  Route? calculatedRoute;

  RoutingExample(this.hereMapController)
      : navigationSettings = NavigationSettings(hereMapController),
        routeCalculator = RouteCalculator();

  List<InstallationPoints> parseData() {
    List<InstallationPoints> ip = [];
    IpData().ipData['InstallationPoints']!.forEach((element) {
      ip.add(InstallationPoints.fromJson(element));
    });

    log(ip.toString());

    return ip;
  }

  Future<void> calculateRouteFromCurrentLocation() async {
    var currentLocation = navigationSettings.getLastKnownLocation();
    if (currentLocation == null) {
      print("Error: No current location found.");
      return;
    }

    double distanceToEarthInMeters = 5000;
    var newOrientation = GeoOrientationUpdate(null, null);
    MapMeasure mapMeasureZoom = MapMeasure(MapMeasureKind.distance, distanceToEarthInMeters);
    hereMapController.camera.lookAtPointWithGeoOrientationAndMeasure(
      currentLocation.coordinates,
      newOrientation,
      mapMeasureZoom,
    );
    List<InstallationPoints> allInstallationPoints = parseData();
    List<InstallationPoints> installationPoints = [];

    //Change the maxIP to load more or less points to the Map
    int maxIP = 15;

    navigationSettings.removeAllMapMarker();

    Uint8List imageToCollect = await NavigationSettings.loadFileAsUint8List('assets/poi.png');
    for (int i = 0; i < maxIP; i++) {
      navigationSettings.addPOIMapMarker(
          GeoCoordinates(double.parse((double.parse((allInstallationPoints[i].latitude!))).toStringAsFixed(7)), double.parse((double.parse(allInstallationPoints[i].longitude!)).toStringAsFixed(7))),
          imageToCollect,
          allInstallationPoints[i]);
      installationPoints.add(allInstallationPoints[i]);
    }

    List<Waypoint> waypoints = await createWaypointsList(installationPoints, currentLocation);

    routeCalculator.calculateTruckRoute(waypoints, (RoutingError? routingError, List<Route>? routeList) async {
      if (routingError == null) {
        calculatedRoute = routeList!.first;
        startNavigationOnRoute(calculatedRoute!);
      } else {
        print("Error optimization: $routingError");
      }
    });
  }

  void startNavigationOnRoute(Route route) {
    navigationSettings.startNavigation(route);
  }

  static Future<List<Waypoint>> createWaypointsList(List<InstallationPoints> installationPoints, Location currentLocation) async {
    List<Waypoint> waypoints = [];

    var startWaypoint = Waypoint(currentLocation.coordinates);

    startWaypoint.headingInDegrees = currentLocation.bearingInDegrees;
    waypoints.add(startWaypoint);

    installationPoints.forEach((ip) async {
      waypoints.add(Waypoint(GeoCoordinates(double.parse(ip.latitude!), double.parse(ip.longitude!))));
    });

    return waypoints;
  }
}
