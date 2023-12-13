import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/routing.dart';

class RouteCalculator {
  late final OfflineRoutingEngine _routingEngine;

  RouteCalculator() {
    try {
      _routingEngine = OfflineRoutingEngine();
    } on InstantiationException {
      throw Exception('Initialization of RoutingEngine failed.');
    }
  }

  void calculateTruckRoute(List<Waypoint> waypoints, CalculateRouteCallback calculateRouteCallback) {
    var routingOptions = TruckOptions();
    routingOptions.routeOptions.enableRouteHandle = true;
    routingOptions.routeOptions.optimizeWaypointsOrder = true;
    routingOptions.routeOptions.optimizationMode = OptimizationMode.fastest;
    _routingEngine.calculateTruckRoute(waypoints, routingOptions, calculateRouteCallback);
  }
}
