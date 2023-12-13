
import 'dart:developer';
import 'dart:math' as MATH;

import 'package:flutter/cupertino.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/maploader.dart';

class NavigationOffline with ChangeNotifier {
  late MapDownloader _mapDownloader;
  late MapUpdater _mapUpdater;
  List<Region> _downloadableRegions = [];
  List<MapDownloaderTask> _mapDownloaderTasks = [];

  NavigationOffline() {
    SDKNativeEngine? sdkNativeEngine = SDKNativeEngine.sharedInstance;
    if (sdkNativeEngine == null) {
      throw ("SDKNativeEngine not initialized.");
    }

    MapDownloader.fromSdkEngineAsync(sdkNativeEngine, (mapDownloader) {
      _mapDownloader = mapDownloader;
    });

    MapUpdater.fromSdkEngineAsync(sdkNativeEngine, (mapUpdater) {
      _mapUpdater = mapUpdater;
    });
  }

  MapDownloader get mapDownloader => _mapDownloader;


  Future<void> downloadListRegionsPT() async {
    if (_mapDownloader == null) {
      log("Note MapDownloader instance not ready. Try again.");
      return;
    }

    log("Downloading the list of available regions.");

    _mapDownloader.getDownloadableRegionsWithLanguageCode(LanguageCode.ptPt, (MapLoaderError? mapLoaderError, List<Region>? list) async {
      if (mapLoaderError != null) {
        log("Error Downloadable regions error: $mapLoaderError");
        return;
      }

      // If error is null, it is guaranteed that the list will not be null.
      _downloadableRegions = list!;

      for (Region region in _downloadableRegions) {
        print("RegionsCallback: " + region.name);
        List<Region>? childRegions = region.childRegions;
        if (childRegions == null) {
          continue;
        }

        // Note that this code ignores to list the children of the children (and so on).
        for (Region childRegion in childRegions) {
          var sizeOnDiskInMB = childRegion.sizeOnDiskInBytes / (1024 * 1024);
          String logMessage = "Child region: " + childRegion.name + ", ID: " + childRegion.regionId.id.toString() + ", Size: " + sizeOnDiskInMB.toString() + " MB";
          print("RegionsCallback: " + logMessage);
        }
      }

      var listLenght = _downloadableRegions.length;
      log("Contintents found: $listLenght Each continent contains various countries. See log for details.");

      await downloadMapRegionsPT();
    });
  }

  Future<void> downloadMapRegionsPT() async {
    if (_mapDownloader == null) {
      log("Note MapDownloader instance not ready. Try again.");
      return;
    }

    log("Downloading one region See log for progress.");

    // Note that we requested the list of regions in German above.
    String portugal = "Portugal";
    Region? region = _findRegion(portugal);

    if (region == null) {
      log("Error: The $portugal region was not found. Click 'Get Regions' first.");
      return;
    }

    // For this example we download only one country.
    List<RegionId> regionIDs = [region.regionId];

    MapDownloaderTask mapDownloaderTask = _mapDownloader.downloadRegions(
        regionIDs,
        DownloadRegionsStatusListener((MapLoaderError? mapLoaderError, List<RegionId>? list) {
          // Handle events from onDownloadRegionsComplete().
          if (mapLoaderError != null) {
            log("Error Download regions completion error: $mapLoaderError");
            return;
          }

          // If error is null, it is guaranteed that the list will not be null.
          // For this example we downloaded only one hardcoded region.
          String message = "Download Regions Status: Completed 100% for Portugal! ID: " + list!.first.id.toString();
          log(message);
        }, (RegionId regionId, int percentage) {
          // Handle events from onProgress().
          String message = "Download of $portugal ID: " + regionId.id.toString() + ". Progress: " + percentage.toString() + "%.";
          log(message);
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            log("Info The download was paused by the user calling mapDownloaderTask.pause().");
          } else {
            log("Error Download regions onPause error. The task tried to often to retry the download: $mapLoaderError");
          }
        }, () {
          // Hnadle events from onResume().
          log("Info A previously paused download has been resumed.");
        }));

    _mapDownloaderTasks.add(mapDownloaderTask);
  }

  // Finds a region in the downloaded region list.
  // Note that we ignore children of children (and so on): For example, a country may contain downloadable sub regions.
  // For this example, we just download the country including possible sub regions.
  Region? _findRegion(String localizedRegionName) {
    Region? downloadableRegion;
    for (Region region in _downloadableRegions) {
      if (region.name == localizedRegionName) {
        downloadableRegion = region;
        break;
      }

      List<Region>? childRegions = region.childRegions;
      if (childRegions == null) {
        continue;
      }

      for (Region childRegion in childRegions) {
        if (childRegion.name == localizedRegionName) {
          downloadableRegion = childRegion;
          break;
        }
      }
    }

    return downloadableRegion;
  }

  MapUpdater get mapUpdater => _mapUpdater;
}
