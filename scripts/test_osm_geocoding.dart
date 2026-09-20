// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final stops = [
    'THIRUVOTTIYUR',
    'KASIMEDU SIGNAL',
    'PURASAIWALKAM TANK',
    'VALLUVAR KOTTAM',
    'PARRYS CORNER',
    'KANDANCHAVADI',
    'SRP TOOLS',
    'ANNA ARCH',
  ];

  for (final stop in stops) {
    // 1. Nominatim
    final q = Uri.encodeComponent('$stop, Chennai, Tamil Nadu, India');
    final url = 'https://nominatim.openstreetmap.org/search?q=$q&format=json&countrycodes=in&viewbox=79.6,13.4,80.4,12.4&bounded=1&limit=3';
    
    try {
      final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'CollegeBusTracker/1.0'});
      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List;
        if (list.isNotEmpty) {
          final top = list.first;
          print('OSM: $stop -> (${top['lat']}, ${top['lon']}) [${top['display_name']}]');
        } else {
          print('OSM: $stop -> NOT FOUND');
        }
      }
    } catch (e) {
      print('OSM error: $e');
    }
    await Future.delayed(const Duration(milliseconds: 600)); // Respect Nominatim rate limit
  }
}
