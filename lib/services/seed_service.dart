import '../models/route_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// All 10 Chennai bus routes with real GPS stop coordinates
class SeedService {
  static List<RouteModel> get defaultRoutes => [
        RouteModel(
          routeId: 'route_01',
          routeName: 'Route 1 – Anna Nagar',
          stops: [
            'Anna Nagar Tower',
            'Koyambedu Bus Stand',
            'Vadapalani',
            'Ashok Nagar',
            'Ekkattuthangal',
            'Guindy',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.0850, 80.2101), // Anna Nagar Tower
            const LatLng(13.0694, 80.1948), // Koyambedu
            const LatLng(13.0524, 80.2120), // Vadapalani
            const LatLng(13.0358, 80.2172), // Ashok Nagar
            const LatLng(13.0069, 80.2206), // Ekkattuthangal
            const LatLng(12.9916, 80.2209), // Guindy
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:30 AM',
          eveningSchedule: '5:00 PM',
        ),
        RouteModel(
          routeId: 'route_02',
          routeName: 'Route 2 – T Nagar',
          stops: [
            'T Nagar Bus Terminus',
            'Saidapet',
            'Guindy',
            'St. Thomas Mount',
            'Chromepet',
            'Pallavaram',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.0418, 80.2341), // T Nagar
            const LatLng(13.0210, 80.2293), // Saidapet
            const LatLng(12.9916, 80.2209), // Guindy
            const LatLng(12.9847, 80.1991), // St Thomas Mount
            const LatLng(12.9516, 80.1416), // Chromepet
            const LatLng(12.9675, 80.1490), // Pallavaram
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:00 AM',
          eveningSchedule: '5:30 PM',
        ),
        RouteModel(
          routeId: 'route_03',
          routeName: 'Route 3 – Tambaram',
          stops: [
            'Tambaram',
            'Chromepet',
            'Pallavaram',
            'St. Thomas Mount',
            'Guindy',
            'Saidapet',
            'College',
          ],
          stopCoordinates: [
            const LatLng(12.9249, 80.1000), // Tambaram
            const LatLng(12.9516, 80.1416), // Chromepet
            const LatLng(12.9675, 80.1490), // Pallavaram
            const LatLng(12.9847, 80.1991), // St Thomas Mount
            const LatLng(12.9916, 80.2209), // Guindy
            const LatLng(13.0210, 80.2293), // Saidapet
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '6:45 AM',
          eveningSchedule: '5:15 PM',
        ),
        RouteModel(
          routeId: 'route_04',
          routeName: 'Route 4 – Velachery',
          stops: [
            'Velachery',
            'Taramani',
            'Perungudi',
            'Sholinganallur',
            'Pallikaranai',
            'Medavakkam',
            'College',
          ],
          stopCoordinates: [
            const LatLng(12.9815, 80.2180), // Velachery
            const LatLng(12.9892, 80.2464), // Taramani
            const LatLng(12.9651, 80.2466), // Perungudi
            const LatLng(12.9003, 80.2275), // Sholinganallur
            const LatLng(12.9325, 80.2121), // Pallikaranai
            const LatLng(12.9215, 80.1936), // Medavakkam
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:15 AM',
          eveningSchedule: '5:00 PM',
        ),
        RouteModel(
          routeId: 'route_05',
          routeName: 'Route 5 – Porur',
          stops: [
            'Porur',
            'Valasaravakkam',
            'Virugambakkam',
            'Kodambakkam',
            'Vadapalani',
            'Koyambedu',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.0358, 80.1577), // Porur
            const LatLng(13.0479, 80.1751), // Valasaravakkam
            const LatLng(13.0537, 80.2012), // Virugambakkam
            const LatLng(13.0501, 80.2209), // Kodambakkam
            const LatLng(13.0524, 80.2120), // Vadapalani
            const LatLng(13.0694, 80.1948), // Koyambedu
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:00 AM',
          eveningSchedule: '5:30 PM',
        ),
        RouteModel(
          routeId: 'route_06',
          routeName: 'Route 6 – Perambur',
          stops: [
            'Perambur',
            'Villivakkam',
            'Kolathur',
            'Mogappair',
            'Anna Nagar East',
            'Koyambedu',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.1143, 80.2416), // Perambur
            const LatLng(13.0955, 80.2072), // Villivakkam
            const LatLng(13.1000, 80.1993), // Kolathur
            const LatLng(13.0892, 80.1782), // Mogappair
            const LatLng(13.0820, 80.2134), // Anna Nagar East
            const LatLng(13.0694, 80.1948), // Koyambedu
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '6:30 AM',
          eveningSchedule: '5:00 PM',
        ),
        RouteModel(
          routeId: 'route_07',
          routeName: 'Route 7 – Adyar',
          stops: [
            'Adyar',
            'Thiruvanmiyur',
            'Besant Nagar',
            'Kotturpuram',
            'Saidapet',
            'Guindy',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.0012, 80.2565), // Adyar
            const LatLng(12.9829, 80.2591), // Thiruvanmiyur
            const LatLng(13.0006, 80.2658), // Besant Nagar
            const LatLng(13.0186, 80.2520), // Kotturpuram
            const LatLng(13.0210, 80.2293), // Saidapet
            const LatLng(12.9916, 80.2209), // Guindy
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:30 AM',
          eveningSchedule: '5:15 PM',
        ),
        RouteModel(
          routeId: 'route_08',
          routeName: 'Route 8 – Avadi',
          stops: [
            'Avadi',
            'Ambattur',
            'Padi',
            'Mogappair',
            'Koyambedu',
            'Vadapalani',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.1146, 80.0993), // Avadi
            const LatLng(13.1148, 80.1548), // Ambattur
            const LatLng(13.0971, 80.1803), // Padi
            const LatLng(13.0892, 80.1782), // Mogappair
            const LatLng(13.0694, 80.1948), // Koyambedu
            const LatLng(13.0524, 80.2120), // Vadapalani
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '6:15 AM',
          eveningSchedule: '5:45 PM',
        ),
        RouteModel(
          routeId: 'route_09',
          routeName: 'Route 9 – OMR / IT Corridor',
          stops: [
            'Siruseri SIPCOT',
            'Perungudi',
            'Sholinganallur',
            'Karapakkam',
            'Taramani',
            'Thiruvanmiyur',
            'College',
          ],
          stopCoordinates: [
            const LatLng(12.8263, 80.2218), // Siruseri SIPCOT
            const LatLng(12.9651, 80.2466), // Perungudi
            const LatLng(12.9003, 80.2275), // Sholinganallur
            const LatLng(12.9266, 80.2308), // Karapakkam
            const LatLng(12.9892, 80.2464), // Taramani
            const LatLng(12.9829, 80.2591), // Thiruvanmiyur
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '7:00 AM',
          eveningSchedule: '5:30 PM',
        ),
        RouteModel(
          routeId: 'route_10',
          routeName: 'Route 10 – Poonamallee',
          stops: [
            'Poonamallee',
            'Maduravoyal',
            'Alapakkam',
            'Porur',
            'Valasaravakkam',
            'Koyambedu',
            'College',
          ],
          stopCoordinates: [
            const LatLng(13.0470, 80.0970), // Poonamallee
            const LatLng(13.0614, 80.1484), // Maduravoyal
            const LatLng(13.0455, 80.1671), // Alapakkam
            const LatLng(13.0358, 80.1577), // Porur
            const LatLng(13.0479, 80.1751), // Valasaravakkam
            const LatLng(13.0694, 80.1948), // Koyambedu
            const LatLng(12.9716, 80.2200), // College
          ],
          assignedDriverId: '',
          morningSchedule: '6:30 AM',
          eveningSchedule: '5:00 PM',
        ),
      ];
}
