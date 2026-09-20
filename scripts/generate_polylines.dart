// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Polyline Encoder (Google Encoded Polyline Algorithm Format)
String encodePolyline(List<List<double>> points) {
  final buffer = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  for (final point in points) {
    int lat = (point[0] * 1e5).round();
    int lng = (point[1] * 1e5).round();

    int dLat = lat - prevLat;
    int dLng = lng - prevLng;

    _encodeValue(dLat, buffer);
    _encodeValue(dLng, buffer);

    prevLat = lat;
    prevLng = lng;
  }

  return buffer.toString();
}

void _encodeValue(int value, StringBuffer buffer) {
  int v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}

/// Fetch road-following polyline points via OSRM public routing API
Future<List<List<double>>> fetchRoadPolyline(List<List<double>> coords) async {
  if (coords.length < 2) return coords;

  try {
    // Format: lng,lat;lng,lat...
    final coordsStr = coords.map((c) => '${c[1]},${c[0]}').join(';');
    final url = 'http://router.project-osrm.org/route/v1/driving/$coordsStr?overview=full&geometries=geojson';
    
    final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'BusTrackerPolylineGen/2.0'});
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
        final geom = data['routes'][0]['geometry']['coordinates'] as List;
        // GeoJSON is [lng, lat], convert to [lat, lng]
        return geom.map<List<double>>((pt) => [double.parse(pt[1].toString()), double.parse(pt[0].toString())]).toList();
      }
    }
  } catch (e) {
    print('  [OSRM Error] $e');
  }

  // Fallback to straight segments if routing fails
  return coords;
}

void main() async {
  print('=====================================================================');
  print('ROAD POLYLINE GENERATOR (PHASE 3)');
  print('=====================================================================');

  final inputFile = File('morning_routes_import_data.json');
  if (!inputFile.existsSync()) {
    print('Error: morning_routes_import_data.json not found! Run scripts/import_morning_routes.dart first.');
    return;
  }

  final List<dynamic> routes = json.decode(inputFile.readAsStringSync());
  print('Loaded ${routes.length} routes from JSON.\n');

  int polylinesGenerated = 0;
  int singleStopSkipped = 0;

  for (int i = 0; i < routes.length; i++) {
    final route = routes[i] as Map<String, dynamic>;
    final routeNum = route['routeNumber'];
    final routeName = route['routeName'];
    final isSingleStop = route['singleStop'] == true || (route['stops'] as List).length <= 1;
    final stopCoords = (route['stopCoordinates'] as List).map<List<double>>((s) {
      return [double.parse(s['lat'].toString()), double.parse(s['lng'].toString())];
    }).toList();

    if (isSingleStop) {
      print('Route $routeNum: $routeName -> Single Stop Route (Skipping polyline)');
      route['polylinePoints'] = '';
      singleStopSkipped++;
      continue;
    }

    print('Generating Road Polyline for Route $routeNum: $routeName (${stopCoords.length} stops)...');
    
    // Chunking for routes with more than 25 waypoints
    List<List<double>> fullRoadPath = [];
    const chunkSize = 20;

    for (int start = 0; start < stopCoords.length - 1; start += chunkSize) {
      final end = (start + chunkSize + 1 < stopCoords.length) ? start + chunkSize + 1 : stopCoords.length;
      final chunk = stopCoords.sublist(start, end);
      
      final roadSegment = await fetchRoadPolyline(chunk);
      if (fullRoadPath.isNotEmpty && roadSegment.isNotEmpty) {
        fullRoadPath.addAll(roadSegment.sublist(1));
      } else {
        fullRoadPath.addAll(roadSegment);
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final encoded = encodePolyline(fullRoadPath);
    route['polylinePoints'] = encoded;
    route['roadPointsCount'] = fullRoadPath.length;
    polylinesGenerated++;

    print('  -> Generated ${fullRoadPath.length} street points (encoded length: ${encoded.length} chars)');
  }

  print('\n=====================================================================');
  print('POLYLINE GENERATION SUMMARY:');
  print('=====================================================================');
  print('Total Routes Evaluated       : ${routes.length}');
  print('Road Polylines Generated     : $polylinesGenerated');
  print('Single-Stop Routes (Skipped) : $singleStopSkipped');
  print('=====================================================================\n');

  // Save updated JSON
  final jsonStr = const JsonEncoder.withIndent('  ').convert(routes);
  await File('morning_routes_import_data.json').writeAsString(jsonStr);
  await File('morning_routes_with_polylines.json').writeAsString(jsonStr);
  await File('admin_dashboard/js/morning-routes-data.js').writeAsString('export const MORNING_ROUTES_DATA = $jsonStr;\n');

  print('Updated datasets saved to:');
  print('  - morning_routes_import_data.json');
  print('  - morning_routes_with_polylines.json');
  print('  - admin_dashboard/js/morning-routes-data.js\n');
}
