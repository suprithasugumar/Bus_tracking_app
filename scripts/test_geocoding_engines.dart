// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final queries = [
    'THIRUVOTTIYUR, Chennai, Tamil Nadu, India',
    'KASIMEDU SIGNAL, Chennai, Tamil Nadu, India',
    'PURASAIWALKAM TANK, Chennai, Tamil Nadu, India',
    'VALLUVAR KOTTAM, Chennai, Tamil Nadu, India',
    'PARRYS CORNER, Chennai, Tamil Nadu, India',
    'KANDANCHAVADI, Chennai, Tamil Nadu, India',
    'SRP TOOLS, Chennai, Tamil Nadu, India',
    'ANNA ARCH, Chennai, Tamil Nadu, India',
    'GERUGAMBAKKAM, Chennai, Tamil Nadu, India',
    'AMBATTUR OT, Chennai, Tamil Nadu, India',
  ];

  for (final q in queries) {
    print('=== Testing query: $q ===');
    // 1. Photon
    try {
      final pUrl = 'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&lat=13.0827&lon=80.2707&bbox=79.6,12.4,80.4,13.4&limit=3';
      final pResp = await http.get(Uri.parse(pUrl));
      if (pResp.statusCode == 200) {
        final pData = json.decode(pResp.body);
        final features = pData['features'] as List;
        if (features.isNotEmpty) {
          for (final f in features) {
            final coords = f['geometry']['coordinates'];
            final props = f['properties'];
            print('  [Photon] (${coords[1]}, ${coords[0]}) - ${props['name']}, ${props['city'] ?? props['county']}');
          }
        } else {
          print('  [Photon] No result');
        }
      }
    } catch (e) {
      print('  [Photon] Error: $e');
    }

    // 2. Nominatim
    try {
      final nUrl = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&countrycodes=in&viewbox=79.6,13.4,80.4,12.4&bounded=1&limit=3';
      final nResp = await http.get(Uri.parse(nUrl), headers: {'User-Agent': 'CollegeBusTrackerGeocode/1.0'});
      if (nResp.statusCode == 200) {
        final nData = json.decode(nResp.body) as List;
        if (nData.isNotEmpty) {
          for (final item in nData) {
            print('  [Nominatim] (${item['lat']}, ${item['lon']}) - ${item['display_name']} [type: ${item['type']}]');
          }
        } else {
          print('  [Nominatim] No result');
        }
      }
    } catch (e) {
      print('  [Nominatim] Error: $e');
    }
    await Future.delayed(const Duration(milliseconds: 1000));
  }
}
