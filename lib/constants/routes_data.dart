import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Central data class for a bus route
class RouteInfo {
  final String routeId;    // short ID used as Firestore document key
  final String routeName;  // display name
  final List<String> stops;
  final List<LatLng> coordinates; // one coordinate per stop

  const RouteInfo({
    required this.routeId,
    required this.routeName,
    required this.stops,
    required this.coordinates,
  });
}

/// All available bus routes with approximate real Chennai coordinates
const List<RouteInfo> appRoutes = [
  RouteInfo(
    routeId: 'route_1',
    routeName: 'Route 1 - Anna Nagar',
    stops: ['Anna Nagar', 'Koyambedu', 'Vadapalani', 'College'],
    coordinates: [
      LatLng(13.0850, 80.2101), // Anna Nagar
      LatLng(13.0703, 80.1947), // Koyambedu
      LatLng(13.0533, 80.2112), // Vadapalani
      LatLng(13.0200, 80.2127), // College
    ],
  ),
  RouteInfo(
    routeId: 'route_2',
    routeName: 'Route 2 - T Nagar',
    stops: ['T Nagar', 'Saidapet', 'Guindy', 'College'],
    coordinates: [
      LatLng(13.0388, 80.2321), // T Nagar
      LatLng(13.0213, 80.2247), // Saidapet
      LatLng(13.0067, 80.2206), // Guindy
      LatLng(13.0200, 80.2127), // College
    ],
  ),
  RouteInfo(
    routeId: 'route_3',
    routeName: 'Route 3 - Tambaram',
    stops: ['Tambaram', 'Chrompet', 'Pallavaram', 'College'],
    coordinates: [
      LatLng(12.9249, 80.1000), // Tambaram
      LatLng(12.9516, 80.1413), // Chrompet
      LatLng(12.9673, 80.1509), // Pallavaram
      LatLng(13.0200, 80.2127), // College
    ],
  ),
];

/// Helper: find a RouteInfo by its routeId
RouteInfo? findRouteById(String routeId) {
  try {
    return appRoutes.firstWhere((r) => r.routeId == routeId);
  } catch (_) {
    return null;
  }
}
