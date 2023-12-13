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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';

import 'RoutingExample.dart';
import 'navigation_offline.dart';
import 'package:here_sdk/consent.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
  _initializeHERESDK();

  // Ensure that all widgets, including MyApp, have a MaterialLocalizations object available.
  runApp(MaterialApp(home: MyApp()));
}

void _initializeHERESDK() async {
  // Needs to be called before accessing SDKOptions to load necessary libraries.
  SdkContext.init(IsolateOrigin.main);

  //PLEASE USE HERE MAPS SDK VERSION 4.14.5
  // Set your credentials for the HERE SDK.
  String accessKeyId = "";
  String accessKeySecret = "";
  SDKOptions sdkOptions = SDKOptions.withAccessKeySecret(accessKeyId, accessKeySecret);

  try {
    await SDKNativeEngine.makeSharedInstance(sdkOptions);
  } on InstantiationException {
    throw Exception("Failed to initialize the HERE SDK.");
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  RoutingExample? _routingExample;
  ConsentEngine? _consentEngine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HERE SDK - Routing Example'),
      ),
      body: Stack(
        children: [
          HereMap(onMapCreated: _onMapCreated),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              button('Download Map', _downloadMap),
              button('Start Navigation', _startNavigation),
              button('Stop Navigation', _clearMapButtonClicked),
            ],
          ),
        ],
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    try {
      _consentEngine = ConsentEngine();
    } on InstantiationException {
      throw ("Initialization of ConsentEngine failed.");
    }

    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay , (MapError? error) async {
      if (error == null) {
        if (!await requestPermissions()) {
          await _showDialog("Error", "Need Permissions");
          openAppSettings();
          SystemNavigator.pop();
          return;
        }

        if (_consentEngine?.userConsentState == ConsentUserReply.notHandled) {
          await requestConsent();
        }

        _routingExample = RoutingExample(hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  Future<bool> requestPermissions() async {
    if (!await Permission.location.serviceStatus.isEnabled) {
      return false;
    }

    if (!await Permission.location.request().isGranted) {
      return false;
    }

    if (Platform.isAndroid) {
      // This permission is optionally needed on Android devices >= Q to improve the positioning signal.
      Permission.activityRecognition.request();
    }

    // All required permissions granted.
    return true;
  }

  Future<void> requestConsent() async {
    if (!Platform.isIOS) {
      // This shows a localized widget that asks the user if data can be collected or not.
      await _consentEngine?.requestUserConsent(context);
    }
  }

  void _downloadMap() {
    final navigationOffline = NavigationOffline();
    Future.delayed(const Duration(seconds: 1), () async {
      if (navigationOffline.mapDownloader.getInstalledRegions().isEmpty) {
        await navigationOffline.downloadListRegionsPT();
        print("Done");
      } else {
        _startNavigation();
      }
    });
  }

  void _startNavigation() {
    _routingExample?.calculateRouteFromCurrentLocation();
  }

  void _clearMapButtonClicked() {
    _routingExample?.navigationSettings.removeAllMapMarker();
    _routingExample?.navigationSettings.stopNavigation();
  }

  @override
  void dispose() {
    // Free HERE SDK resources before the application shuts down.
    SDKNativeEngine.sharedInstance?.dispose();
    SdkContext.release();
    super.dispose();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Colors.lightBlueAccent,
          onPrimary: Colors.white,
        ),
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }

  // A helper method to show a dialog.
  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
