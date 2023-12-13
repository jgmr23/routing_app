import 'dart:developer';

import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/location.dart';

class HEREPositioningProvider implements LocationStatusListener {
  late LocationEngine locationEngine;
  late LocationListener updateListener;

  HEREPositioningProvider() {
    try {
      locationEngine = LocationEngine();
    } on InstantiationException {
      throw ("Initialization of LocationEngine failed.");
    }
  }

  Location? getLastKnownLocation() {
    return locationEngine.lastKnownLocation;
  }

  void startLocating(LocationListener updateListener, LocationAccuracy accuracy) {
    if (locationEngine.isStarted) {
      return;
    }

    this.updateListener = updateListener;

    // Set listeners to get location updates.
    locationEngine.addLocationListener(updateListener);
    locationEngine.addLocationStatusListener(this);

    locationEngine.startWithLocationAccuracy(accuracy);
  }

  void stop() {
    if (!locationEngine.isStarted) {
      return;
    }

    // Remove listeners and stop location engine.
    locationEngine.removeLocationStatusListener(this);
    locationEngine.removeLocationListener(updateListener);
    locationEngine.stop();
  }

  @override
  void onStatusChanged(LocationEngineStatus locationEngineStatus) {
    log("Location engine status: " + locationEngineStatus.toString());
  }

  @override
  onFeaturesNotAvailable(List<LocationFeature> features) {
    /*for (var feature in features) {
      log("Feature not available: " + feature.toString());
    }*/
  }
}
