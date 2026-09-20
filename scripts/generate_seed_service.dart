// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final jsonFile = File('morning_routes_with_polylines.json');
  if (!jsonFile.existsSync()) {
    print('Error: morning_routes_with_polylines.json not found!');
    return;
  }

  final List<dynamic> routes = json.decode(jsonFile.readAsStringSync());
  print('Loaded ${routes.length} morning routes from JSON.');

  final List<Map<String, dynamic>> updatedRoutes = [];

  final buffer = StringBuffer();
  buffer.writeln("// Generated Seed Service containing all 80 Morning Routes with VIT CHENNAI Destination");
  buffer.writeln("import '../models/route_model.dart';");
  buffer.writeln("import 'package:google_maps_flutter/google_maps_flutter.dart';");
  buffer.writeln("");
  buffer.writeln("class SeedService {");
  buffer.writeln("  static List<RouteModel> get defaultRoutes => [");

  for (final r in routes) {
    final routeId = r['routeId'];
    final routeNum = r['routeNumber'];
    final routeName = r['routeName'];
    final List<dynamic> rawStops = List.from(r['stops'] as List);
    final List<dynamic> rawTimes = List.from(r['scheduledTimes'] as List);
    final List<dynamic> rawCoords = List.from(r['stopCoordinates'] as List);
    final polyline = r['polylinePoints'] ?? '';

    // Check if last stop is already VIT CHENNAI
    final bool hasVitChennai = rawStops.isNotEmpty &&
        rawStops.last.toString().trim().toUpperCase().contains('VIT CHENNAI');

    if (!hasVitChennai) {
      rawStops.add('VIT CHENNAI');
      rawTimes.add('08:00');
      rawCoords.add({
        'name': 'VIT CHENNAI',
        'lat': 12.8406,
        'lng': 80.1534,
      });
    }

    final stops = rawStops.map((s) => "'${s.toString().replaceAll("'", "\\'")}'").toList();
    final scheduledTimes = rawTimes.map((t) => "'$t'").toList();

    buffer.writeln("        RouteModel(");
    buffer.writeln("          routeId: '$routeId',");
    buffer.writeln("          routeName: '$routeNum | $routeName',");
    buffer.writeln("          stops: [${stops.join(', ')}],");
    buffer.writeln("          scheduledTimes: [${scheduledTimes.join(', ')}],");
    buffer.writeln("          encodedPolyline: r'$polyline',");
    buffer.writeln("          stopCoordinates: [");
    for (final sc in rawCoords) {
      final lat = sc['lat'];
      final lng = sc['lng'];
      buffer.writeln("            const LatLng($lat, $lng), // ${sc['name']}");
    }
    buffer.writeln("          ],");
    buffer.writeln("          assignedDriverId: '',");
    buffer.writeln("          morningSchedule: '${scheduledTimes.isNotEmpty ? scheduledTimes.first.replaceAll("'", "") : "07:00"}',");
    buffer.writeln("          eveningSchedule: '17:00',");
    buffer.writeln("        ),");

    final updatedRoute = Map<String, dynamic>.from(r as Map);
    updatedRoute['stops'] = rawStops;
    updatedRoute['scheduledTimes'] = rawTimes;
    updatedRoute['stopCoordinates'] = rawCoords;
    updatedRoutes.add(updatedRoute);
  }

  buffer.writeln("      ];");
  buffer.writeln("}");
  buffer.writeln("");

  final targetFile = File('lib/services/seed_service.dart');
  targetFile.writeAsStringSync(buffer.toString());
  print('Generated ${targetFile.path} successfully with ${routes.length} routes (all ending at VIT CHENNAI)!');

  // Save updated JSONs
  File('morning_routes_with_polylines.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(updatedRoutes),
  );
  File('morning_routes_import_data.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(updatedRoutes),
  );
  File('admin_dashboard/js/morning-routes-data.js').writeAsStringSync(
    'window.MORNING_ROUTES_DATA = ${const JsonEncoder.withIndent('  ').convert(updatedRoutes)};\n',
  );
  print('Saved updated JSON data and admin_dashboard files.');
}
