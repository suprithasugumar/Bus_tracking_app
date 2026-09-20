// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final keys = [
    'AIzaSyD139Cun7rKKouwpfpMZxLSH_gxEXYWpCo',
    'AIzaSyCmDv9TLLW2x36c30Nrq0iUilOpW5kwwcM',
    'AIzaSyC-SJKacY_NCNuoaa8MYzmQc_1fNKgeyJg',
    'AIzaSyDKtBlcymXzL_b_t2gaVZP3WHslGE8yNTs',
  ];

  for (final apiKey in keys) {
    final query = Uri.encodeComponent('THIRUVOTTIYUR, Chennai, Tamil Nadu, India');
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$query&bounds=12.4,79.6|13.4,80.4&components=country:IN&key=$apiKey';
    
    final resp = await http.get(Uri.parse(url));
    final data = json.decode(resp.body);
    print('Key: ${apiKey.substring(0, 10)}... Status: ${data['status']}');
  }
}
