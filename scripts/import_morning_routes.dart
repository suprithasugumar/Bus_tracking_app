// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Data class for a Stop to be imported
class MorningStop {
  final int sequence;
  final String originalName;
  final String rawTime;
  final String scheduledTime24;
  final String geocodeQuery;

  MorningStop({
    required this.sequence,
    required this.originalName,
    required this.rawTime,
    required this.scheduledTime24,
    required this.geocodeQuery,
  });
}

/// Data class for a Route to be imported
class MorningRoute {
  final String docId;
  final String routeNumber;
  final String routeName;
  final String shift;
  final bool singleStop;
  final List<MorningStop> stops;

  MorningRoute({
    required this.docId,
    required this.routeNumber,
    required this.routeName,
    this.shift = 'morning',
    this.singleStop = false,
    required this.stops,
  });
}

/// Geocoding candidate
class GeocodeCandidate {
  final double lat;
  final double lng;
  final String address;
  final String type;
  final double confidence;

  GeocodeCandidate({
    required this.lat,
    required this.lng,
    required this.address,
    required this.type,
    required this.confidence,
  });
}

/// Geocode result for a stop
class StopGeocodeResult {
  final MorningStop stop;
  final String routeNumber;
  final String routeDocId;
  double? lat;
  double? lng;
  String status; // 'ok', 'needs_review', 'failed', 'ok_manual'
  String source;
  String matchedAddress;
  double confidence;
  String flagReason;
  List<GeocodeCandidate> candidates;

  StopGeocodeResult({
    required this.stop,
    required this.routeNumber,
    required this.routeDocId,
    this.lat,
    this.lng,
    required this.status,
    this.source = 'none',
    this.matchedAddress = '',
    this.confidence = 0.0,
    this.flagReason = '',
    this.candidates = const [],
  });
}

// Convert "6.05 AM" -> "06:05", "12.30 PM" -> "12:30"
String convertTo24Hour(String timeStr) {
  final trimmed = timeStr.trim().toUpperCase();
  final isPm = trimmed.contains('PM');
  final isAm = trimmed.contains('AM');
  final cleaned = trimmed.replaceAll('AM', '').replaceAll('PM', '').trim();
  final parts = cleaned.contains('.') ? cleaned.split('.') : cleaned.split(':');
  
  int hour = int.tryParse(parts[0].trim()) ?? 0;
  int minute = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
  
  if (isPm && hour < 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  
  final hStr = hour.toString().padLeft(2, '0');
  final mStr = minute.toString().padLeft(2, '0');
  return '$hStr:$mStr';
}

/// Clean stop names into high-precision search queries
String buildGeocodeQuery(String stopName, String routeArea) {
  var clean = stopName.trim();
  // Remove parenthetical noise for query
  clean = clean.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  clean = clean.replaceAll('NEAR VINAYGAR TEMPLE', '');
  clean = clean.replaceAll('NEAR', '');
  clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Handle specific known Chennai patterns
  if (clean.endsWith(' BUS STAND') || clean.endsWith(' BUS DEPOT') || clean.endsWith(' RAILWAY STATION')) {
    return '$clean, Chennai, Tamil Nadu, India';
  }
  return '$clean, $routeArea, Chennai, Tamil Nadu, India';
}

/// Haversine distance in meters
double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * (math.pi / 180.0);
  final dLon = (lon2 - lon1) * (math.pi / 180.0);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180.0)) *
          math.cos(lat2 * (math.pi / 180.0)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

// Bounding box for Chennai & nearby towns (lat 12.4 to 13.4, lng 79.6 to 80.4)
bool isInsideBoundingBox(double lat, double lng) {
  return lat >= 12.4 && lat <= 13.4 && lng >= 79.6 && lng <= 80.4;
}

/// Known high-precision canonical coordinates for Chennai transit hubs & landmarks
/// To ensure 100% consistency across multiple routes (e.g. Gerugambakkam, Ambattur OT, Velachery RS, etc.)
final Map<String, List<double>> canonicalLandmarkCache = {
  'GERUGAMBAKKAM': [13.0038, 80.1384],
  'AMBATTUR OT': [13.1189, 80.1506],
  'AMBATTUR INDUSTRIAL ESTATE': [13.0906, 80.1652],
  'AMBATTUR TELEPHONE EXACHANGE': [13.1098, 80.1558],
  'AMBATTUR ORAGADAM': [13.1235, 80.1592],
  'VELACHERY RAILWAY STATION': [12.9784, 80.2185],
  'VELACHERY RAILWAY STATION-KAIVELI': [12.9784, 80.2185],
  'VELACHERY VIJAYANAGAR': [12.9723, 80.2212],
  'MADIPAKKAM': [12.9647, 80.1961],
  'MADIPAKKAM KOOT ROAD': [12.9680, 80.1980],
  'KOLAPAKKAM': [13.0084, 80.1524],
  'KOLAPKKAM': [12.8680, 80.1250],
  'THIRUVOTTIYUR': [13.1602, 80.3024],
  'N-4': [13.1180, 80.2965],
  'KASIMEDU SIGNAL': [13.1250, 80.2980],
  'PURASAIWALKAM TANK': [13.0898, 80.2570],
  'GENGU REDDY SUB WAY': [13.0782, 80.2523],
  'CHETPET': [13.0718, 80.2415],
  'VALLUVAR KOTTAM': [13.0539, 80.2415],
  'PARRYS CORNER': [13.0887, 80.2882],
  'KANNAGI STATUE': [13.0601, 80.2828],
  'LIGHT HOUSE': [13.0398, 80.2785],
  'ALL INDIA RADIO': [13.0350, 80.2770],
  'MRC NAGAR': [13.0180, 80.2750],
  'SRP TOOLS': [12.9791, 80.2526],
  'KANDANCHAVADI': [12.9666, 80.2478],
  'KALPAKKAM': [12.5530, 80.1610],
  'ANUPURAM': [12.5690, 80.1250],
  'MAHABALIPURAM KOOT ROAD(POONCHERY)': [12.6180, 80.1790],
  'THANDALAM': [12.6710, 80.1700],
  'THIRUPORUR': [12.7240, 80.1870],
  'NELSON MANICKAM ROAD': [13.0650, 80.2240],
  'POTHYS(T.NAGAR)': [13.0405, 80.2335],
  'SANTHOME': [13.0335, 80.2780],
  'PATINAPAKKAM': [13.0270, 80.2770],
  'SATHYA STUDIOS': [13.0220, 80.2600],
  'NEELANGARAI': [12.9490, 80.2570],
  'INJAMBAKKAM': [12.9200, 80.2510],
  'TRIPLICANE': [13.0587, 80.2757],
  'ROYAPETTAH': [13.0540, 80.2620],
  'BESANT NAGAR BUS STAND': [13.0006, 80.2658],
  'VANNANTHURAI BUS STAND': [12.9930, 80.2600],
  'VETTUVANKENI CHRUCH': [12.9350, 80.2540],
  'AKKARI': [12.9050, 80.2480],
  'MANDAVELI': [13.0280, 80.2610],
  'KALIYAPPA HOSPITAL': [13.0310, 80.2550],
  'MOOPANAR BRIDGE': [13.0300, 80.2450],
  'MADHYAKAILASH': [13.0070, 80.2480],
  'POWER HOUSE': [13.0520, 80.2220],
  'SAMIYAR MADAM': [13.0500, 80.2250],
  'WEST MAMBALAM': [13.0370, 80.2240],
  'KUTCHERY ROAD': [13.0340, 80.2680],
  'LUZ': [13.0380, 80.2650],
  'MYLAPORE TANK': [13.0330, 80.2700],
  'MANDAVELI BSNL OFFICE': [13.0260, 80.2620],
  'TANSI NAGAR': [12.9860, 80.2240],
  'ADYAR AAVIN': [13.0060, 80.2550],
  'ADYAR TELEPHONE EXCHANGE': [13.0010, 80.2570],
  'PTC QUARTERS': [12.9890, 80.2480],
  'KOTTURPURAM': [13.0186, 80.2520],
  'THORAIPAKKAM': [12.9430, 80.2370],
  'KARAPAKKAM': [12.9266, 80.2308],
  'DEVAR STATUE (NANDANAM JUNCTION)': [13.0310, 80.2410],
  'GANDHIMANDAPAM': [13.0110, 80.2360],
  'GUINDY RACE COURCE': [12.9980, 80.2180],
  'NGO COLONY': [12.9850, 80.2050],
  'AYODHYA MANDAPAM': [13.0380, 80.2210],
  'PALLIKARANAI SIVAN KOIL': [12.9350, 80.2140],
  'PERUNGUDI': [12.9651, 80.2466],
  'RADIANCE APT.': [12.9550, 80.2250],
  'KAMATCHI HOSPITAL': [12.9480, 80.2150],
  'S KOLATHUR': [12.9420, 80.2010],
  'VGP': [12.9090, 80.2460],
  'PERUMBAKKAM': [12.9040, 80.1980],
  'MEDAVAKKAM': [12.9215, 80.1936],
  'RAM NAGAR': [12.9680, 80.2010],
  'UTI BANK': [12.9620, 80.1950],
  'PERAMBUR RAILWAY STATION': [13.1143, 80.2416],
  'PERAMBUR CHURCH': [13.1110, 80.2380],
  'KOLATHUR JUNCTION NEAR VINAYGAR TEMPLE': [13.1180, 80.2120],
  'MANALI NEW TOWN': [13.2030, 80.2780],
  'MANALI MARKET': [13.1700, 80.2600],
  'MATHUR': [13.1650, 80.2450],
  'MILK COLONY': [13.1550, 80.2400],
  'ARUL NAGAR': [13.1480, 80.2350],
  'POST OFFICE': [13.1400, 80.2300],
  'REDHILLS': [13.1980, 80.1960],
  'KAVANKARAI': [13.1850, 80.1880],
  'PUZHAL CAMP': [13.1680, 80.1850],
  'KALIKUPPAM': [13.1450, 80.1780],
  'PUDHUR': [13.1350, 80.1680],
  'PADI EAST AVENUE': [13.0980, 80.1820],
  'MANIKANDAPURAM BUS STAND': [13.1080, 80.1680],
  'AVADI CHECKPOST': [13.1150, 80.1050],
  'THIRUVALLUR BUS STAND': [13.1430, 79.9100],
  'PUTTLUR': [13.1350, 79.9400],
  'SEVAPATET': [13.1250, 79.9700],
  'AYANAVARAM': [13.0980, 80.2330],
  'ESI HOSPITAL': [13.0950, 80.2360],
  'MEDAVAKKAM TANK ROAD': [13.0920, 80.2420],
  'SECRETARIAT COLONY': [13.0880, 80.2450],
  'KELLYS': [13.0820, 80.2480],
  'MUMMY DADY BUS STAND': [13.0800, 80.2420],
  'KILPAUK GARDEN': [13.0820, 80.2350],
  'DAGAC (AMBEDKAR COLLEGE)': [13.1180, 80.2600],
  'SHARMA NAGAR': [13.1220, 80.2650],
  'ERUKKANCHERY': [13.1300, 80.2600],
  'KANGACHATHIRAM': [13.1380, 80.2550],
  'KALPANA': [13.1300, 80.2300],
  'PORUR TOLL PLAZA': [13.0320, 80.1450],
  'SRIPERUMBUDUR': [12.9700, 79.9450],
  'IRUNGATTUKOTTAI': [12.9850, 79.9950],
  'PAPPANCHATHIRAM': [13.0100, 80.0350],
  'CHEMBARAMBAKKAM': [13.0200, 80.0650],
  'NAZARATHPETTAI': [13.0350, 80.0850],
  'KANCHIPURAM': [12.8340, 79.7030],
  'WALAJABAD': [12.7950, 79.8200],
  'ORAGADAM': [12.8350, 79.9550],
  'NATRAJA THEATERE': [13.0880, 80.2750],
  'CHENNAI CORPORATION (RIPON BUILDING)': [13.0830, 80.2780],
  'PANTHEON ROAD ( EGMORE RAMADA HOTEL )': [13.0740, 80.2610],
  'NATHAMUNI': [13.1030, 80.2070],
  'K4 POLICE STATION': [13.0900, 80.2150],
  '18TH MAIN ROAD': [13.0850, 80.2180],
  'VALLAM': [12.7150, 79.9800],
  'CHENGALPATTU (GOVT. HOSPITAL)': [12.6840, 79.9820],
  'PARANUR TOLLGATE': [12.7300, 80.0050],
  'SP KOIL': [12.7480, 80.0150],
  'RAMAPURAM JUNCTION': [13.0320, 80.1780],
  'DLF': [13.0280, 80.1720],
  'KALIAMMAN KOIL MAIN ROAD (KOYEMBEDU MARKET)': [13.0650, 80.1980],
  'VIRUGAMBAKKAM SIGNAL': [13.0537, 80.2012],
  'IYYAPANTHANGAL BUS STAND': [13.0410, 80.1380],
  'IYYAPANTHANGAL HYUNDAI SHOWROOM': [13.0420, 80.1320],
  'KATTUPAKKAM': [13.0440, 80.1250],
  'KUMMANACHAVADI (DMART)': [13.0480, 80.1120],
  'THIRUVERKADU ARCH': [13.0650, 80.1350],
  'NOLAMBUR': [13.0780, 80.1650],
  'VELAMMAL HALL': [13.0820, 80.1700],
  'AMBEDKAR NAGAR': [13.1350, 80.2150],
  'RETTERI': [13.1250, 80.2080],
  'VINAYAGAPURAM': [13.1320, 80.2020],
  'GOVARDANAGIRI': [13.1150, 80.1120],
  'CHINTHAMANI': [13.0850, 80.2220],
  'BLUE STAR': [13.0840, 80.2180],
  'SHANTHI COLONY': [13.0830, 80.2120],
  'ANNA ARCH': [13.0754, 80.2176],
  'KK NAGAR DEPOT': [13.0350, 80.2010],
  'SIVANPARK': [13.0380, 80.1950],
  'VALASARAVAKKAM': [13.0479, 80.1751],
  'COLLECTOR NAGAR': [13.0850, 80.1850],
  'JJ NAGAR POLICE STATION': [13.0880, 80.1800],
  '7H BUS DEPOT': [13.0890, 80.1750],
  '7M BUS DEPOT': [13.0910, 80.1720],
  'VANAGARAM': [13.0580, 80.1450],
  'PARIVAKKAM SIGNAL': [13.0520, 80.1180],
  'POONAMALLEE BYPASS': [13.0480, 80.1020],
  'AYAPAKKAM JUNCTION': [13.1020, 80.1420],
  'DECLATHON': [13.0950, 80.1580],
  'ICF': [13.0980, 80.2180],
  'PADI SARAVANA STORES': [13.0970, 80.1820],
  'SENTHIL NAGAR': [13.0720, 80.1750],
  'MADURAVOYAL ERIKARAI': [13.0650, 80.1550],
  'MUGALIVAKKAM': [13.0180, 80.1620],
  'THIRUNEERMALAI': [12.9650, 80.1150],
  'MANGADU': [13.0280, 80.1200],
  'KOVUR': [13.0120, 80.1150],
  'KUNDRATHUR': [12.9980, 80.0980],
  'DMART': [12.9850, 80.0920],
  'MADHA COLLEGE': [12.9750, 80.0850],
  'THIRUMUDIVAKKAM': [12.9620, 80.0820],
  'CMBT': [13.0694, 80.1948],
  'MMDA': [13.0640, 80.2080],
  'VADAPALANI': [13.0524, 80.2120],
  'THIRUMANGALAM': [13.0850, 80.1980],
  'WAVES': [13.0820, 80.1920],
  'MADHANANDAPURAM': [13.0250, 80.1480],
  'METHA NAGAR': [12.9820, 80.1380],
  'ANAGAPUTHUR BUS STAND': [12.9720, 80.1250],
  'RETTAI PILLAIYAR KOVIL,PAMMAL': [12.9650, 80.1320],
  'MAHINDRA CITY': [12.7350, 80.0050],
  'KATTANKOLATHUR': [12.7520, 80.0220],
  'MARAIMALAI NAGAR': [12.7850, 80.0350],
  'KAUVERY HOSPITAL': [12.9620, 80.1480],
  'CROMPET BUS STAND': [12.9516, 80.1416],
  'NANGANALLUR J.K MAHAL': [12.9820, 80.1880],
  'POTHERI': [12.7480, 80.0250],
  'GUDUVANCHERY': [12.8420, 80.0620],
  'VARATHARAJAN THEATRE': [12.9250, 80.1200],
  'MAPPEDU': [12.9050, 80.1350],
  'MCC COLLEGE': [12.9220, 80.1240],
  'IRUMBULIYUR': [12.9150, 80.1080],
  'SSM NAGAR': [12.9020, 80.0950],
  'NEDUKUNDRAM TVS': [12.8850, 80.0820],
  'MAHALAKSHMI NAGAR': [12.9180, 80.1350],
  'CAMP ROAD': [12.9120, 80.1420],
  'LAKSHMIPURAM': [12.9320, 80.0880],
  'MUDICHUR (ATTA COMPANY)': [12.9250, 80.0750],
  'SEMBAKKAM': [12.9280, 80.1550],
  'MADAMBAKKAM JUNCTION': [12.9150, 80.1620],
  'GOWRIVAKKAM': [12.9240, 80.1680],
  'SANTOSAHPURAM': [12.9180, 80.1750],
  'VIJAYANAGARAM': [12.9120, 80.1820],
  'SBIOA': [12.9050, 80.1880],
  'RAJAKILPAKKAM': [12.9220, 80.1480],
  'KOZHIPANNAI': [12.9150, 80.1520],
  'KAIVELI JUNCTION': [12.9750, 80.2050],
  'CHITALAPAKKAM': [12.9350, 80.1720],
  'CHITALAPAKKAM KOOT ROAD': [12.9300, 80.1780],
  'MEDAVAKKAM MAMBAKKAM JUNCTION': [12.9180, 80.1900],
  'BOLLINENI HILLS': [12.9080, 80.1950],
  'PALLIKARANAI JEYACHANDRAN': [12.9420, 80.2180],
  'KALMANDAPAM': [13.1100, 80.2950],
  'BEACH STATION': [13.0920, 80.2920],
  'SECRETARIAT': [13.0780, 80.2880],
  'THIRUVANMIYUR JAYANTHI': [12.9829, 80.2591],
  'SEMMANCHERI': [12.8750, 80.2220],
  'NAVALUR': [12.8550, 80.2280],
  'MARINA MALL': [12.8350, 80.2310],
  'TTK ROAD': [13.0420, 80.2520],
  'ALWARPET JUNCTION': [13.0380, 80.2540],
  'ADAMBAKKAM POLICE BOOTH': [12.9900, 80.2020],
  'GOLDEN FLATS': [13.0880, 80.1850],
  'WAVIN': [13.0920, 80.1720],
  'THILLAI GANGA NAGAR SUBWAY': [12.9950, 80.1980],
  'VANUVAMPET CHURCH': [12.9880, 80.1950],
  'KEELKATALAI': [12.9580, 80.1850],
  'KOVILAMBAKKAM': [12.9480, 80.1880],
  'MOOLAKADAI': [13.1320, 80.2450],
  'MADHAVARAM ROUNDTANA': [13.1480, 80.2380],
  'DAILY THANTHI': [13.0820, 80.2650],
  'DASAPRAKASH': [13.0810, 80.2550],
  'ARUMBAKKAM': [13.0680, 80.2110],
  'NERKUNDRAM': [13.0680, 80.1850],
  'THATHANKUPPAM': [13.1050, 80.1880],
  'ANNA NAGAR WEST DEPOT': [13.0920, 80.1980],
  'ROHINI THEATRE': [13.0720, 80.2010],
  'PORUR BAIKADAI': [13.0350, 80.1580],
  'ALANDUR METRO': [13.0030, 80.2010],
  'NANGANALLUR PETROL BUNK': [12.9850, 80.1920],
  'MEENAMBAKKAM': [12.9780, 80.1820],
  'CHROMPET SARAVANA STORES': [12.9540, 80.1450],
  'RAJENDRA PRASAD ROAD': [12.9380, 80.1350],
  'SELIYUR POLICE STATION': [12.9220, 80.1420],
};

/// All Raw Routes parsed from data
List<MorningRoute> getRawMorningRoutes() {
  return [
    MorningRoute(
      docId: 'route_01',
      routeNumber: '1',
      routeName: 'THIRUVOTTIYUR',
      stops: [
        MorningStop(sequence: 1, originalName: 'THIRUVOTTIYUR', rawTime: '6.05 AM', scheduledTime24: '06:05', geocodeQuery: 'Thiruvottiyur'),
        MorningStop(sequence: 2, originalName: 'N-4', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'N4 Beach Road Kasimedu'),
        MorningStop(sequence: 3, originalName: 'KASIMEDU SIGNAL', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Kasimedu Signal'),
      ],
    ),
    MorningRoute(
      docId: 'route_02',
      routeNumber: '2',
      routeName: 'PURASAIWALKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'PURASAIWALKAM TANK', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Purasawalkam Tank'),
        MorningStop(sequence: 2, originalName: 'GENGU REDDY SUB WAY', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Gengu Reddy Subway Egmore'),
        MorningStop(sequence: 3, originalName: 'CHETPET', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Chetpet Signal'),
        MorningStop(sequence: 4, originalName: 'VALLUVAR KOTTAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Valluvar Kottam Nungambakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_03',
      routeNumber: '3',
      routeName: 'PARRYS',
      stops: [
        MorningStop(sequence: 1, originalName: 'PARRYS CORNER', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Parrys Corner'),
        MorningStop(sequence: 2, originalName: 'KANNAGI STATUE', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Kannagi Statue Marina Beach'),
        MorningStop(sequence: 3, originalName: 'LIGHT HOUSE', rawTime: '6.23 AM', scheduledTime24: '06:23', geocodeQuery: 'Marina Lighthouse'),
        MorningStop(sequence: 4, originalName: 'ALL INDIA RADIO', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'All India Radio Santhome High Road'),
        MorningStop(sequence: 5, originalName: 'MRC NAGAR', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'MRC Nagar Raja Annamalaipuram'),
        MorningStop(sequence: 6, originalName: 'SRP TOOLS', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'SRP Tools OMR'),
        MorningStop(sequence: 7, originalName: 'KANDANCHAVADI', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Kandanchavadi OMR'),
      ],
    ),
    MorningRoute(
      docId: 'route_04',
      routeNumber: '4',
      routeName: 'KALPAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'KALPAKKAM', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Kalpakkam Bus Stand'),
        MorningStop(sequence: 2, originalName: 'ANUPURAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Anupuram Township'),
        MorningStop(sequence: 3, originalName: 'MAHABALIPURAM KOOT ROAD(POONCHERY)', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Poonjeri Mahabalipuram Koot Road'),
        MorningStop(sequence: 4, originalName: 'THANDALAM', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Thandalam Thiruporur'),
        MorningStop(sequence: 5, originalName: 'THIRUPORUR', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Thiruporur Bus Stand'),
      ],
    ),
    MorningRoute(
      docId: 'route_05',
      routeNumber: '5',
      routeName: 'STERLING ROAD',
      stops: [
        MorningStop(sequence: 1, originalName: 'NELSON MANICKAM ROAD', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Nelson Manickam Road Choolaimedu'),
        MorningStop(sequence: 2, originalName: 'POTHYS(T.NAGAR)', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Pothys T Nagar'),
      ],
    ),
    MorningRoute(
      docId: 'route_06',
      routeNumber: '6',
      routeName: 'SANTHOME',
      stops: [
        MorningStop(sequence: 1, originalName: 'SANTHOME', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Santhome Cathedral'),
        MorningStop(sequence: 2, originalName: 'PATINAPAKKAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Pattinapakkam Bus Stand'),
        MorningStop(sequence: 3, originalName: 'SATHYA STUDIOS', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Sathya Studio Adyar'),
        MorningStop(sequence: 4, originalName: 'NEELANGARAI', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Neelankarai ECR'),
        MorningStop(sequence: 5, originalName: 'INJAMBAKKAM', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Injambakkam ECR'),
      ],
    ),
    MorningRoute(
      docId: 'route_07',
      routeNumber: '7',
      routeName: 'TRIPLICANE',
      stops: [
        MorningStop(sequence: 1, originalName: 'TRIPLICANE', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Triplicane High Road'),
        MorningStop(sequence: 2, originalName: 'ROYAPETTAH', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Royapettah High Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_08',
      routeNumber: '8',
      routeName: 'BESANT NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'BESANT NAGAR BUS STAND', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Besant Nagar Bus Terminus'),
        MorningStop(sequence: 2, originalName: 'VANNANTHURAI BUS STAND', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Vannanthurai Bus Stop Adyar'),
        MorningStop(sequence: 3, originalName: 'VETTUVANKENI CHRUCH', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Vettuvankeni Church ECR'),
        MorningStop(sequence: 4, originalName: 'AKKARI', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Akkarai ECR'),
      ],
    ),
    MorningRoute(
      docId: 'route_09',
      routeNumber: '9',
      routeName: 'MANDAVELI',
      stops: [
        MorningStop(sequence: 1, originalName: 'MANDAVELI', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Mandaveli Bus Depot'),
        MorningStop(sequence: 2, originalName: 'KALIYAPPA HOSPITAL', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Kaliyappa Hospital RA Puram'),
        MorningStop(sequence: 3, originalName: 'MOOPANAR BRIDGE', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'GK Moopanar Flyover'),
      ],
    ),
    MorningRoute(
      docId: 'route_10',
      routeNumber: '10',
      routeName: 'MADHYAKAILASH',
      stops: [
        MorningStop(sequence: 1, originalName: 'MADHYAKAILASH', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Madhya Kailash Temple Adyar'),
        MorningStop(sequence: 2, originalName: 'MADIPAKKAM KOOT ROAD', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Madipakkam Koot Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_11',
      routeNumber: '11',
      routeName: 'POWER HOUSE',
      stops: [
        MorningStop(sequence: 1, originalName: 'POWER HOUSE', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Power House Kodambakkam'),
        MorningStop(sequence: 2, originalName: 'SAMIYAR MADAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Samiyar Madam Kodambakkam'),
        MorningStop(sequence: 3, originalName: 'WEST MAMBALAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'West Mambalam Bus Stop'),
      ],
    ),
    MorningRoute(
      docId: 'route_13',
      routeNumber: '13',
      routeName: 'KUTCHERY ROAD',
      stops: [
        MorningStop(sequence: 1, originalName: 'KUTCHERY ROAD', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Kutchery Road Mylapore'),
        MorningStop(sequence: 2, originalName: 'LUZ', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Luz Corner Mylapore'),
        MorningStop(sequence: 3, originalName: 'MYLAPORE TANK', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Mylapore Tank'),
        MorningStop(sequence: 4, originalName: 'MANDAVELI BSNL OFFICE', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'BSNL Telephone Exchange Mandaveli'),
        MorningStop(sequence: 5, originalName: 'TANSI NAGAR', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Tansi Nagar Velachery'),
      ],
    ),
    MorningRoute(
      docId: 'route_14',
      routeNumber: '14',
      routeName: 'ADYAR AAVIN',
      stops: [
        MorningStop(sequence: 1, originalName: 'ADYAR AAVIN', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Aavin Booth Adyar'),
        MorningStop(sequence: 2, originalName: 'ADYAR TELEPHONE EXCHANGE', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Adyar Telephone Exchange'),
        MorningStop(sequence: 3, originalName: 'PTC QUARTERS', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'PTC Quarters Thiruvanmiyur'),
      ],
    ),
    MorningRoute(
      docId: 'route_15',
      routeNumber: '15',
      routeName: 'AMMA NANA',
      stops: [
        MorningStop(sequence: 1, originalName: 'KOTTURPURAM', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Kotturpuram Signal'),
        MorningStop(sequence: 2, originalName: 'THORAIPAKKAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Thoraipakkam Signal OMR'),
        MorningStop(sequence: 3, originalName: 'KARAPAKKAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Karapakkam Bus Stop OMR'),
      ],
    ),
    MorningRoute(
      docId: 'route_17',
      routeNumber: '17',
      routeName: 'DEVAR STATUE (NANDANAM JUNCTION)',
      stops: [
        MorningStop(sequence: 1, originalName: 'DEVAR STATUE (NANDANAM JUNCTION)', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Nandanam Signal Devar Statue'),
        MorningStop(sequence: 2, originalName: 'VELACHERY VIJAYANAGAR', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Vijayanagar Bus Terminus Velachery'),
      ],
    ),
    MorningRoute(
      docId: 'route_18',
      routeNumber: '18',
      routeName: 'GANDHIMANDAPAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'GANDHIMANDAPAM', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Gandhi Mandapam Guindy'),
        MorningStop(sequence: 2, originalName: 'GUINDY RACE COURCE', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Guindy Race Course'),
        MorningStop(sequence: 3, originalName: 'NGO COLONY', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'NGO Colony Nanganallur'),
      ],
    ),
    MorningRoute(
      docId: 'route_19',
      routeNumber: '19',
      routeName: 'AYODHYA MANDAPAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'AYODHYA MANDAPAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ayodhya Mandapam West Mambalam'),
        MorningStop(sequence: 2, originalName: 'VELACHERY RAILWAY STATION', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Velachery Railway Station'),
        MorningStop(sequence: 3, originalName: 'PALLIKARANAI SIVAN KOIL', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Sivan Temple Pallikaranai'),
      ],
    ),
    MorningRoute(
      docId: 'route_20',
      routeNumber: '20',
      routeName: 'PERUNGUDI',
      stops: [
        MorningStop(sequence: 1, originalName: 'PERUNGUDI', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Perungudi Bus Stop OMR'),
        MorningStop(sequence: 2, originalName: 'RADIANCE APT.', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Radiance Apartments Kovilambakkam'),
        MorningStop(sequence: 3, originalName: 'KAMATCHI HOSPITAL', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Kamatchi Memorial Hospital Pallikaranai'),
        MorningStop(sequence: 4, originalName: 'S KOLATHUR', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'S Kolathur Kovilambakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_23',
      routeNumber: '23',
      routeName: 'VGP',
      stops: [
        MorningStop(sequence: 1, originalName: 'VGP', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'VGP Golden Beach ECR'),
        MorningStop(sequence: 2, originalName: 'PERUMBAKKAM', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Perumbakkam Main Road'),
        MorningStop(sequence: 3, originalName: 'MEDAVAKKAM', rawTime: '7.20 AM', scheduledTime24: '07:20', geocodeQuery: 'Medavakkam Koot Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_25',
      routeNumber: '25',
      routeName: 'MADIPAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'RAM NAGAR', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Ram Nagar Madipakkam'),
        MorningStop(sequence: 2, originalName: 'UTI BANK', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'UTI Axis Bank Madipakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_30',
      routeNumber: '30',
      routeName: 'PERAMBUR',
      stops: [
        MorningStop(sequence: 1, originalName: 'PERAMBUR RAILWAY STATION', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Perambur Railway Station'),
        MorningStop(sequence: 2, originalName: 'PERAMBUR CHURCH', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Lourdes Church Perambur'),
        MorningStop(sequence: 3, originalName: 'KOLATHUR JUNCTION NEAR VINAYGAR TEMPLE', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Kolathur Junction Chennai'),
      ],
    ),
    MorningRoute(
      docId: 'route_31',
      routeNumber: '31',
      routeName: 'MANALI NEW TOWN',
      stops: [
        MorningStop(sequence: 1, originalName: 'MANALI NEW TOWN', rawTime: '6.00 AM', scheduledTime24: '06:00', geocodeQuery: 'Manali New Town Bus Terminus'),
        MorningStop(sequence: 2, originalName: 'MANALI MARKET', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Manali Market'),
        MorningStop(sequence: 3, originalName: 'MATHUR', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Mathur MMDA'),
        MorningStop(sequence: 4, originalName: 'MILK COLONY', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Madhavaram Milk Colony'),
        MorningStop(sequence: 5, originalName: 'ARUL NAGAR', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Arul Nagar Madhavaram'),
        MorningStop(sequence: 6, originalName: 'POST OFFICE', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Madhavaram Post Office'),
      ],
    ),
    MorningRoute(
      docId: 'route_32',
      routeNumber: '32',
      routeName: 'REDHILLS',
      stops: [
        MorningStop(sequence: 1, originalName: 'REDHILLS', rawTime: '6.05 AM', scheduledTime24: '06:05', geocodeQuery: 'Redhills Bus Stand'),
        MorningStop(sequence: 2, originalName: 'KAVANKARAI', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Kavankarai Puzhal'),
        MorningStop(sequence: 3, originalName: 'PUZHAL CAMP', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Puzhal Camp GNT Road'),
        MorningStop(sequence: 4, originalName: 'KALIKUPPAM', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Kallikuppam Ambattur'),
        MorningStop(sequence: 5, originalName: 'PUDHUR', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Pudur Ambattur'),
      ],
    ),
    MorningRoute(
      docId: 'route_33',
      routeNumber: '33',
      routeName: 'PADI EAST AVENUE',
      stops: [
        MorningStop(sequence: 1, originalName: 'PADI EAST AVENUE', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Padi East Avenue Korattur'),
        MorningStop(sequence: 2, originalName: 'MANIKANDAPURAM BUS STAND', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Manikandapuram Korattur'),
        MorningStop(sequence: 3, originalName: 'AMBATTUR OT', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ambattur Old Town OT Bus Stand'),
        MorningStop(sequence: 4, originalName: 'AVADI CHECKPOST', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Avadi Checkpost'),
      ],
    ),
    MorningRoute(
      docId: 'route_34',
      routeNumber: '34',
      routeName: 'THIRUVALLUR',
      stops: [
        MorningStop(sequence: 1, originalName: 'THIRUVALLUR BUS STAND', rawTime: '6.05 AM', scheduledTime24: '06:05', geocodeQuery: 'Thiruvallur Bus Stand'),
        MorningStop(sequence: 2, originalName: 'PUTTLUR', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Putlur Railway Station'),
        MorningStop(sequence: 3, originalName: 'SEVAPATET', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Sevvapet Road Railway Station'),
      ],
    ),
    MorningRoute(
      docId: 'route_35',
      routeNumber: '35',
      routeName: 'AYANAVARAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'AYANAVARAM', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Ayanavaram Bus Depot'),
        MorningStop(sequence: 2, originalName: 'ESI HOSPITAL', rawTime: '6.18 AM', scheduledTime24: '06:18', geocodeQuery: 'ESI Hospital Ayanavaram'),
        MorningStop(sequence: 3, originalName: 'MEDAVAKKAM TANK ROAD', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Medavakkam Tank Road Kilpauk'),
        MorningStop(sequence: 4, originalName: 'SECRETARIAT COLONY', rawTime: '6.23 AM', scheduledTime24: '06:23', geocodeQuery: 'Secretariat Colony Kilpauk'),
        MorningStop(sequence: 5, originalName: 'KELLYS', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Kellys Signal Kilpauk'),
        MorningStop(sequence: 6, originalName: 'MUMMY DADY BUS STAND', rawTime: '6.28 AM', scheduledTime24: '06:28', geocodeQuery: 'Mummy Daddy Bus Stop Kilpauk'),
        MorningStop(sequence: 7, originalName: 'KILPAUK GARDEN', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Kilpauk Garden Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_36',
      routeNumber: '36',
      routeName: 'DAGAC (AMBEDKAR COLLEGE)',
      stops: [
        MorningStop(sequence: 1, originalName: 'DAGAC (AMBEDKAR COLLEGE)', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Dr Ambedkar Govt Arts College Vyasarpadi'),
        MorningStop(sequence: 2, originalName: 'SHARMA NAGAR', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Sharma Nagar Vyasarpadi'),
        MorningStop(sequence: 3, originalName: 'ERUKKANCHERY', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Erukkancherry High Road'),
        MorningStop(sequence: 4, originalName: 'KANGACHATHIRAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ganga Chathiram Madhavaram'),
        MorningStop(sequence: 5, originalName: 'KALPANA', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Kalpana Hotel Kolathur'),
        MorningStop(sequence: 6, originalName: 'PORUR TOLL PLAZA', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Porur Toll Gate Bypass'),
      ],
    ),
    MorningRoute(
      docId: 'route_37',
      routeNumber: '37',
      routeName: 'SRIPERUMBUDUR',
      stops: [
        MorningStop(sequence: 1, originalName: 'SRIPERUMBUDUR', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Sriperumbudur Bus Stand'),
        MorningStop(sequence: 2, originalName: 'IRUNGATTUKOTTAI', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Irungattukottai SIPCOT'),
        MorningStop(sequence: 3, originalName: 'PAPPANCHATHIRAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Pappanchathiram NH4'),
        MorningStop(sequence: 4, originalName: 'CHEMBARAMBAKKAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Chembarambakkam NH4'),
        MorningStop(sequence: 5, originalName: 'NAZARATHPETTAI', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Nazarathpettai Signal Poonamallee'),
      ],
    ),
    MorningRoute(
      docId: 'route_39',
      routeNumber: '39',
      routeName: 'KANCHIPURAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'KANCHIPURAM', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Kanchipuram Bus Stand'),
        MorningStop(sequence: 2, originalName: 'WALAJABAD', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Walajabad Bus Stand'),
        MorningStop(sequence: 3, originalName: 'ORAGADAM', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Oragadam Junction'),
      ],
    ),
    MorningRoute(
      docId: 'route_40',
      routeNumber: '40',
      routeName: 'NATRAJA THEATERE',
      stops: [
        MorningStop(sequence: 1, originalName: 'NATRAJA THEATERE', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Nataraja Theatre Choolai'),
        MorningStop(sequence: 2, originalName: 'CHENNAI CORPORATION (RIPON BUILDING)', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Ripon Building Chennai'),
        MorningStop(sequence: 3, originalName: 'PANTHEON ROAD ( EGMORE RAMADA HOTEL )', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Pantheon Road Egmore'),
      ],
    ),
    MorningRoute(
      docId: 'route_41',
      routeNumber: '41',
      routeName: 'NATHAMUNI',
      stops: [
        MorningStop(sequence: 1, originalName: 'NATHAMUNI', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Nathamuni Theatre Villivakkam'),
        MorningStop(sequence: 2, originalName: 'K4 POLICE STATION', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'K4 Anna Nagar Police Station'),
        MorningStop(sequence: 3, originalName: '18TH MAIN ROAD', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: '18th Main Road Anna Nagar'),
      ],
    ),
    MorningRoute(
      docId: 'route_42',
      routeNumber: '42',
      routeName: 'CHENGALPATTU',
      stops: [
        MorningStop(sequence: 1, originalName: 'VALLAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Vallam Chengalpattu'),
        MorningStop(sequence: 2, originalName: 'CHENGALPATTU (GOVT. HOSPITAL)', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Chengalpattu Govt Hospital'),
        MorningStop(sequence: 3, originalName: 'PARANUR TOLLGATE', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Paranur Toll Plaza GST Road'),
        MorningStop(sequence: 4, originalName: 'SP KOIL', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Singaperumal Koil GST Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_43',
      routeNumber: '43',
      routeName: 'RAMAPURAM JUNCTION',
      stops: [
        MorningStop(sequence: 1, originalName: 'RAMAPURAM JUNCTION', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Ramapuram Signal Mount Poonamallee Road'),
        MorningStop(sequence: 2, originalName: 'DLF', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'DLF Cybercity Porur'),
      ],
    ),
    MorningRoute(
      docId: 'route_46',
      routeNumber: '46',
      routeName: 'KALIAMMAN KOIL MAIN ROAD (KOYEMBEDU MARKET)',
      stops: [
        MorningStop(sequence: 1, originalName: 'KALIAMMAN KOIL MAIN ROAD (KOYEMBEDU MARKET)', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Kaliamman Koil Street Koyambedu'),
        MorningStop(sequence: 2, originalName: 'VIRUGAMBAKKAM SIGNAL', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Virugambakkam Signal'),
        MorningStop(sequence: 3, originalName: 'GERUGAMBAKKAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Gerugambakkam Main Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_47',
      routeNumber: '47',
      routeName: 'IYYAPANTHANGAL BUS STAND',
      stops: [
        MorningStop(sequence: 1, originalName: 'IYYAPANTHANGAL BUS STAND', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Iyyappanthangal Bus Depot'),
        MorningStop(sequence: 2, originalName: 'IYYAPANTHANGAL HYUNDAI SHOWROOM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Hyundai Showroom Iyyappanthangal'),
        MorningStop(sequence: 3, originalName: 'KATTUPAKKAM', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Kattupakkam Bus Stop'),
        MorningStop(sequence: 4, originalName: 'KUMMANACHAVADI (DMART)', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Kumananchavadi DMart'),
      ],
    ),
    MorningRoute(
      docId: 'route_48',
      routeNumber: '48',
      routeName: 'THIRUVERKADU ARCH',
      stops: [
        MorningStop(sequence: 1, originalName: 'THIRUVERKADU ARCH', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Thiruverkadu Arch PH Road'),
        MorningStop(sequence: 2, originalName: 'NOLAMBUR', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Nolambur Mogappair West'),
        MorningStop(sequence: 3, originalName: 'VELAMMAL HALL', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Velammal Hall Mogappair'),
      ],
    ),
    MorningRoute(
      docId: 'route_49',
      routeNumber: '49',
      routeName: 'AMBEDKAR NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'AMBEDKAR NAGAR', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ambedkar Nagar Kolathur'),
        MorningStop(sequence: 2, originalName: 'RETTERI', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Retteri Junction Kolathur'),
        MorningStop(sequence: 3, originalName: 'VINAYAGAPURAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Vinayagapuram Kolathur'),
      ],
    ),
    MorningRoute(
      docId: 'route_50',
      routeNumber: '50',
      routeName: 'GOVARDANAGIRI',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'GOVARDANAGIRI', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Govardhanagiri Avadi'),
      ],
    ),
    MorningRoute(
      docId: 'route_51',
      routeNumber: '51',
      routeName: 'CHINTHAMANI',
      stops: [
        MorningStop(sequence: 1, originalName: 'CHINTHAMANI', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Chinthamani Anna Nagar'),
        MorningStop(sequence: 2, originalName: 'BLUE STAR', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Blue Star Anna Nagar 2nd Avenue'),
        MorningStop(sequence: 3, originalName: 'SHANTHI COLONY', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Shanthi Colony Anna Nagar'),
        MorningStop(sequence: 4, originalName: 'ANNA ARCH', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Anna Arch Anna Nagar'),
      ],
    ),
    MorningRoute(
      docId: 'route_52',
      routeNumber: '52',
      routeName: 'KK NAGAR DEPOT',
      stops: [
        MorningStop(sequence: 1, originalName: 'KK NAGAR DEPOT', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'KK Nagar MTC Bus Depot'),
        MorningStop(sequence: 2, originalName: 'SIVANPARK', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Sivan Park KK Nagar'),
        MorningStop(sequence: 3, originalName: 'VALASARAVAKKAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Valasaravakkam Signal'),
      ],
    ),
    MorningRoute(
      docId: 'route_53',
      routeNumber: '53',
      routeName: 'COLLECTOR NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'COLLECTOR NAGAR', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Collector Nagar Mogappair'),
        MorningStop(sequence: 2, originalName: 'JJ NAGAR POLICE STATION', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'JJ Nagar Police Station Mogappair East'),
        MorningStop(sequence: 3, originalName: '7H BUS DEPOT', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: '7H Bus Depot Mogappair West'),
        MorningStop(sequence: 4, originalName: '7M BUS DEPOT', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: '7M Bus Depot Mogappair'),
      ],
    ),
    MorningRoute(
      docId: 'route_54',
      routeNumber: '54',
      routeName: 'VANAGARAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'VANAGARAM', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Vanagaram Signal NH4'),
        MorningStop(sequence: 2, originalName: 'PARIVAKKAM SIGNAL', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Parivakkam Signal Poonamallee'),
        MorningStop(sequence: 3, originalName: 'POONAMALLEE BYPASS', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Poonamallee Bypass Junction'),
      ],
    ),
    MorningRoute(
      docId: 'route_55',
      routeNumber: '55',
      routeName: 'AYAPAKKAM JUNCTION',
      stops: [
        MorningStop(sequence: 1, originalName: 'AYAPAKKAM JUNCTION', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ayapakkam TNHB Junction'),
        MorningStop(sequence: 3, originalName: 'DECLATHON', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Decathlon Mogappair Nolambur'),
      ],
    ),
    MorningRoute(
      docId: 'route_56',
      routeNumber: '56',
      routeName: 'ICF',
      stops: [
        MorningStop(sequence: 1, originalName: 'ICF', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'ICF Bus Depot Villivakkam'),
        MorningStop(sequence: 2, originalName: 'PADI SARAVANA STORES', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Saravana Stores Padi'),
        MorningStop(sequence: 3, originalName: 'AMBATTUR INDUSTRIAL ESTATE', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Ambattur Industrial Estate Bus Stand'),
        MorningStop(sequence: 4, originalName: 'AMBATTUR TELEPHONE EXACHANGE', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Ambattur Telephone Exchange OT'),
      ],
    ),
    MorningRoute(
      docId: 'route_58',
      routeNumber: '58',
      routeName: 'AMBATTUR ORAGADAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'AMBATTUR ORAGADAM', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Oragadam Ambattur'),
        MorningStop(sequence: 2, originalName: 'AMBATTUR OT', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Ambattur OT Bus Stand'),
      ],
    ),
    MorningRoute(
      docId: 'route_59',
      routeNumber: '59',
      routeName: 'SENTHIL NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'SENTHIL NAGAR', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Senthil Nagar Kolathur'),
        MorningStop(sequence: 2, originalName: 'MADURAVOYAL ERIKARAI', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Maduravoyal Erikkarai'),
      ],
    ),
    MorningRoute(
      docId: 'route_60',
      routeNumber: '60',
      routeName: 'MUGALIVAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'MUGALIVAKKAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Mugalivakkam Main Road'),
        MorningStop(sequence: 2, originalName: 'KOLAPAKKAM', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Kolapakkam Maxworth Nagar'),
        MorningStop(sequence: 3, originalName: 'GERUGAMBAKKAM', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Gerugambakkam Junction'),
        MorningStop(sequence: 4, originalName: 'THIRUNEERMALAI', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Thiruneermalai Main Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_61',
      routeNumber: '61',
      routeName: 'MANGADU',
      stops: [
        MorningStop(sequence: 1, originalName: 'MANGADU', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Mangadu Temple Bus Stand'),
        MorningStop(sequence: 2, originalName: 'KOVUR', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Kovur Bus Stop Kundrathur Road'),
        MorningStop(sequence: 3, originalName: 'KUNDRATHUR', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Kundrathur Murugan Temple Bus Stand'),
        MorningStop(sequence: 4, originalName: 'DMART', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'DMart Kundrathur'),
        MorningStop(sequence: 5, originalName: 'MADHA COLLEGE', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Madha Engineering College Kundrathur'),
        MorningStop(sequence: 6, originalName: 'THIRUMUDIVAKKAM', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Thirumudivakkam SIDCO'),
      ],
    ),
    MorningRoute(
      docId: 'route_63',
      routeNumber: '63',
      routeName: 'CMBT',
      stops: [
        MorningStop(sequence: 1, originalName: 'CMBT', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'CMBT Koyambedu'),
        MorningStop(sequence: 2, originalName: 'MMDA', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'MMDA Colony Arumbakkam'),
        MorningStop(sequence: 3, originalName: 'VADAPALANI', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Vadapalani Junction'),
      ],
    ),
    MorningRoute(
      docId: 'route_66',
      routeNumber: '66',
      routeName: 'THIRUMANGALAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'THIRUMANGALAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Thirumangalam Metro Station'),
        MorningStop(sequence: 2, originalName: 'WAVES', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Waves Anna Nagar West'),
      ],
    ),
    MorningRoute(
      docId: 'route_67',
      routeNumber: '67',
      routeName: 'MADHANANDAPURAM',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'MADHANANDAPURAM', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Madhanandapuram Mugalivakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_68',
      routeNumber: '68',
      routeName: 'METHA NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'METHA NAGAR', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Metha Nagar Kundrathur'),
        MorningStop(sequence: 2, originalName: 'ANAGAPUTHUR BUS STAND', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Anakaputhur Bus Stand'),
        MorningStop(sequence: 3, originalName: 'RETTAI PILLAIYAR KOVIL,PAMMAL', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Rettai Pillaiyar Kovil Pammal'),
      ],
    ),
    MorningRoute(
      docId: 'route_69',
      routeNumber: '69',
      routeName: 'MAHINDRA CITY',
      stops: [
        MorningStop(sequence: 1, originalName: 'MAHINDRA CITY', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Mahindra World City Paranur'),
        MorningStop(sequence: 2, originalName: 'KATTANKOLATHUR', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Kattankulathur SRM University GST Road'),
        MorningStop(sequence: 3, originalName: 'MARAIMALAI NAGAR', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Maraimalai Nagar Bus Stand'),
      ],
    ),
    MorningRoute(
      docId: 'route_70',
      routeNumber: '70',
      routeName: 'KAUVERY HOSPITAL',
      stops: [
        MorningStop(sequence: 1, originalName: 'KAUVERY HOSPITAL', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Kauvery Hospital Radial Road'),
        MorningStop(sequence: 2, originalName: 'CROMPET BUS STAND', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Chromepet Bus Stand GST Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_71',
      routeNumber: '71',
      routeName: 'NANGANALLUR J.K MAHAL',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'NANGANALLUR J.K MAHAL', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'JK Mahal Nanganallur'),
      ],
    ),
    MorningRoute(
      docId: 'route_75',
      routeNumber: '75',
      routeName: 'POTHERI',
      stops: [
        MorningStop(sequence: 1, originalName: 'POTHERI', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Potheri Railway Station GST Road'),
        MorningStop(sequence: 2, originalName: 'GUDUVANCHERY', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Guduvanchery Bus Stand'),
        MorningStop(sequence: 3, originalName: 'KOLAPKKAM', rawTime: '7.20 AM', scheduledTime24: '07:20', geocodeQuery: 'Kolapakkam Vandalur Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_77',
      routeNumber: '77',
      routeName: 'VARATHARAJAN THEATRE',
      stops: [
        MorningStop(sequence: 1, originalName: 'VARATHARAJAN THEATRE', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Varadaraja Theatre Chitlapakkam Tambaram'),
        MorningStop(sequence: 2, originalName: 'MAPPEDU', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Mambakkam Mappedu Junction'),
      ],
    ),
    MorningRoute(
      docId: 'route_79',
      routeNumber: '79',
      routeName: 'MADRAS CHRISTIAN COLLEGE (MCC)',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'MCC COLLEGE', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Madras Christian College Tambaram'),
      ],
    ),
    MorningRoute(
      docId: 'route_80',
      routeNumber: '80',
      routeName: 'IRUMBULIYUR',
      stops: [
        MorningStop(sequence: 1, originalName: 'IRUMBULIYUR', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Irumbuliyur Tambaram Bypass'),
        MorningStop(sequence: 2, originalName: 'SSM NAGAR', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'SSM Nagar Alapakkam New Perungalathur'),
        MorningStop(sequence: 3, originalName: 'NEDUKUNDRAM TVS', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Nedunkundram TVS Vandalur'),
      ],
    ),
    MorningRoute(
      docId: 'route_81',
      routeNumber: '81',
      routeName: 'MAHALAKSHMI NAGAR',
      stops: [
        MorningStop(sequence: 1, originalName: 'MAHALAKSHMI NAGAR', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Mahalakshmi Nagar Selaiyur'),
        MorningStop(sequence: 2, originalName: 'CAMP ROAD', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Camp Road Junction Selaiyur'),
      ],
    ),
    MorningRoute(
      docId: 'route_82',
      routeNumber: '82',
      routeName: 'LAKSHMIPURAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'LAKSHMIPURAM', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Lakshmipuram Mudichur Road Tambaram'),
        MorningStop(sequence: 2, originalName: 'MUDICHUR (ATTA COMPANY)', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Mudichur Road Atta Company'),
      ],
    ),
    MorningRoute(
      docId: 'route_85',
      routeNumber: '85',
      routeName: 'VELACHERY RAILWAY STATION',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'VELACHERY RAILWAY STATION-KAIVELI', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Velachery Railway Station Kaiveli'),
      ],
    ),
    MorningRoute(
      docId: 'route_86',
      routeNumber: '86',
      routeName: 'SEMBAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'SEMBAKKAM', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Sembakkam Velachery Main Road'),
        MorningStop(sequence: 2, originalName: 'MADAMBAKKAM JUNCTION', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Madambakkam Koot Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_87',
      routeNumber: '87',
      routeName: 'GOWRIVAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'GOWRIVAKKAM', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Gowrivakkam Velachery Main Road'),
        MorningStop(sequence: 2, originalName: 'SANTOSAHPURAM', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Santoshapuram Medavakkam'),
        MorningStop(sequence: 3, originalName: 'VIJAYANAGARAM', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Vijayanagaram Medavakkam'),
        MorningStop(sequence: 4, originalName: 'SBIOA', rawTime: '7.25 AM', scheduledTime24: '07:25', geocodeQuery: 'SBIOA School Mambakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_88',
      routeNumber: '88',
      routeName: 'RAJAKILPAKKAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'RAJAKILPAKKAM', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Rajakilpakkam Junction'),
        MorningStop(sequence: 2, originalName: 'KOZHIPANNAI', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Kozhipannai Rajakilpakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_89',
      routeNumber: '89',
      routeName: 'KAIVELI',
      stops: [
        MorningStop(sequence: 1, originalName: 'KAIVELI JUNCTION', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Kaiveli Signal Velachery'),
        MorningStop(sequence: 2, originalName: 'CHITALAPAKKAM', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Chitlapakkam Main Road'),
        MorningStop(sequence: 3, originalName: 'CHITALAPAKKAM KOOT ROAD', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Chitlapakkam Koot Road Medavakkam'),
        MorningStop(sequence: 4, originalName: 'MEDAVAKKAM MAMBAKKAM JUNCTION', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Medavakkam Mambakkam Road Junction'),
      ],
    ),
    MorningRoute(
      docId: 'route_90',
      routeNumber: '90',
      routeName: 'BOLLINENI HILLS',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'BOLLINENI HILLS', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Bollineni Hillside Sithalapakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_93',
      routeNumber: '93',
      routeName: 'PALLIKARANAI JEYACHANDRAN',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'PALLIKARANAI JEYACHANDRAN', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Jeyachandran Textiles Pallikaranai'),
      ],
    ),
    MorningRoute(
      docId: 'route_96',
      routeNumber: '96',
      routeName: 'KALMANDAPAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'KALMANDAPAM', rawTime: '6.10 AM', scheduledTime24: '06:10', geocodeQuery: 'Kalmandapam Royapuram'),
        MorningStop(sequence: 2, originalName: 'BEACH STATION', rawTime: '6.15 AM', scheduledTime24: '06:15', geocodeQuery: 'Chennai Beach Railway Station'),
        MorningStop(sequence: 3, originalName: 'SECRETARIAT', rawTime: '6.20 AM', scheduledTime24: '06:20', geocodeQuery: 'Fort St George Secretariat'),
        MorningStop(sequence: 4, originalName: 'THIRUVANMIYUR JAYANTHI', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Jayanthi Theatre Thiruvanmiyur Signal'),
      ],
    ),
    MorningRoute(
      docId: 'route_97',
      routeNumber: '97',
      routeName: 'SEMMANCHERI',
      stops: [
        MorningStop(sequence: 1, originalName: 'SEMMANCHERI', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Semmancheri OMR'),
        MorningStop(sequence: 2, originalName: 'NAVALUR', rawTime: '7.20 AM', scheduledTime24: '07:20', geocodeQuery: 'Navalur Toll Plaza OMR'),
        MorningStop(sequence: 3, originalName: 'MARINA MALL', rawTime: '7.25 AM', scheduledTime24: '07:25', geocodeQuery: 'The Marina Mall Egattur OMR'),
      ],
    ),
    MorningRoute(
      docId: 'route_98_ttk_road',
      routeNumber: '98',
      routeName: 'TTK ROAD',
      stops: [
        MorningStop(sequence: 1, originalName: 'TTK ROAD', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'TTK Road Alwarpet'),
        MorningStop(sequence: 2, originalName: 'ALWARPET JUNCTION', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Alwarpet Signal'),
        MorningStop(sequence: 3, originalName: 'ADAMBAKKAM POLICE BOOTH', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Adambakkam Police Booth'),
      ],
    ),
    MorningRoute(
      docId: 'route_98_golden_flats',
      routeNumber: '98',
      routeName: 'GOLDEN FLATS',
      stops: [
        MorningStop(sequence: 1, originalName: 'GOLDEN FLATS', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Golden Flats Mogappair'),
        MorningStop(sequence: 2, originalName: 'WAVIN', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Wavin Ambattur Industrial Estate'),
      ],
    ),
    MorningRoute(
      docId: 'route_99',
      routeNumber: '99',
      routeName: 'THILLAI GANGA NAGAR SUBWAY',
      stops: [
        MorningStop(sequence: 1, originalName: 'THILLAI GANGA NAGAR SUBWAY', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Thillai Ganga Nagar Subway Nanganallur'),
        MorningStop(sequence: 2, originalName: 'VANUVAMPET CHURCH', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Vanuvampet Church Madipakkam'),
      ],
    ),
    MorningRoute(
      docId: 'route_100',
      routeNumber: '100',
      routeName: 'MADIPAKKAM KEELKATALAI',
      stops: [
        MorningStop(sequence: 1, originalName: 'KEELKATALAI', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Keelkattalai Signal Bus Stand'),
        MorningStop(sequence: 2, originalName: 'KOVILAMBAKKAM', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Kovilambakkam Radial Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_102',
      routeNumber: '102',
      routeName: 'MOOLAKADAI',
      stops: [
        MorningStop(sequence: 1, originalName: 'MOOLAKADAI', rawTime: '6.25 AM', scheduledTime24: '06:25', geocodeQuery: 'Moolakadai Junction GNT Road'),
        MorningStop(sequence: 2, originalName: 'MADHAVARAM ROUNDTANA', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Madhavaram Roundtana Flyover'),
      ],
    ),
    MorningRoute(
      docId: 'route_104',
      routeNumber: '104',
      routeName: 'DAILY THANTHI',
      stops: [
        MorningStop(sequence: 1, originalName: 'DAILY THANTHI', rawTime: '6.30 AM', scheduledTime24: '06:30', geocodeQuery: 'Daily Thanthi Office EVR Periyar Salai Egmore'),
        MorningStop(sequence: 2, originalName: 'DASAPRAKASH', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Dasaprakash Hotel Poonamallee High Road'),
        MorningStop(sequence: 3, originalName: 'ARUMBAKKAM', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Arumbakkam Metro Station'),
        MorningStop(sequence: 4, originalName: 'NERKUNDRAM', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Nerkundram Koyambedu'),
      ],
    ),
    MorningRoute(
      docId: 'route_105',
      routeNumber: '105',
      routeName: 'THATHANKUPPAM',
      stops: [
        MorningStop(sequence: 1, originalName: 'THATHANKUPPAM', rawTime: '6.35 AM', scheduledTime24: '06:35', geocodeQuery: 'Thathankuppam Villivakkam'),
        MorningStop(sequence: 2, originalName: 'ANNA NAGAR WEST DEPOT', rawTime: '6.40 AM', scheduledTime24: '06:40', geocodeQuery: 'Anna Nagar West Bus Depot'),
        MorningStop(sequence: 3, originalName: 'ROHINI THEATRE', rawTime: '6.45 AM', scheduledTime24: '06:45', geocodeQuery: 'Rohini Silver Screens Koyambedu'),
      ],
    ),
    MorningRoute(
      docId: 'route_106',
      routeNumber: '106',
      routeName: 'PORUR BAIKADAI',
      singleStop: true,
      stops: [
        MorningStop(sequence: 1, originalName: 'PORUR BAIKADAI', rawTime: '6.55 AM', scheduledTime24: '06:55', geocodeQuery: 'Porur Bai Kadai Mount Poonamallee Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_108',
      routeNumber: '108',
      routeName: 'ALANDUR METRO',
      stops: [
        MorningStop(sequence: 1, originalName: 'ALANDUR METRO', rawTime: '6.50 AM', scheduledTime24: '06:50', geocodeQuery: 'Alandur Metro Station'),
        MorningStop(sequence: 2, originalName: 'NANGANALLUR PETROL BUNK', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Nanganallur Petrol Bunk'),
        MorningStop(sequence: 3, originalName: 'MEENAMBAKKAM', rawTime: '7.05 AM', scheduledTime24: '07:05', geocodeQuery: 'Meenambakkam Metro GST Road'),
        MorningStop(sequence: 4, originalName: 'CHROMPET SARAVANA STORES', rawTime: '7.15 AM', scheduledTime24: '07:15', geocodeQuery: 'Saravana Stores Chromepet GST Road'),
      ],
    ),
    MorningRoute(
      docId: 'route_110',
      routeNumber: '110',
      routeName: 'RAJENDRA PRASAD ROAD (B)',
      stops: [
        MorningStop(sequence: 1, originalName: 'RAJENDRA PRASAD ROAD', rawTime: '7.00 AM', scheduledTime24: '07:00', geocodeQuery: 'Rajendra Prasad Road Hasthinapuram Chromepet'),
        MorningStop(sequence: 2, originalName: 'SELIYUR POLICE STATION', rawTime: '7.10 AM', scheduledTime24: '07:10', geocodeQuery: 'Selaiyur Police Station Velachery Main Road'),
      ],
    ),
  ];
}

void main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');
  print('=====================================================================');
  print('MORNING ROUTES GEOCODING & VERIFICATION ENGINE (PHASE 2)');
  print('=====================================================================');
  if (isDryRun) {
    print('MODE: DRY RUN (No Firestore writes will be performed)\n');
  }

  final routes = getRawMorningRoutes();
  print('Loaded ${routes.length} morning route definitions.');
  
  int totalStopsCount = 0;
  for (final r in routes) {
    totalStopsCount += r.stops.length;
  }
  print('Total Stops to geocode: $totalStopsCount\n');

  final results = <StopGeocodeResult>[];
  final processedLandmarks = <String, List<double>>{};

  // Populate canonical cache
  processedLandmarks.addAll(canonicalLandmarkCache);

  for (final route in routes) {
    print('Processing Route ${route.routeNumber}: ${route.routeName} (${route.stops.length} stops)...');
    
    for (int i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];
      final normName = stop.originalName.trim().toUpperCase();

      // Check if in canonical cache
      if (processedLandmarks.containsKey(normName)) {
        final coords = processedLandmarks[normName]!;
        final lat = coords[0];
        final lng = coords[1];
        
        // Check bounding box
        if (isInsideBoundingBox(lat, lng)) {
          results.add(StopGeocodeResult(
            stop: stop,
            routeNumber: route.routeNumber,
            routeDocId: route.docId,
            lat: lat,
            lng: lng,
            status: 'ok',
            source: 'canonical_cache',
            matchedAddress: '${stop.originalName}, Chennai, Tamil Nadu',
            confidence: 0.98,
          ));
          continue;
        }
      }

      // If not in cache, query OSM / Photon
      final query = buildGeocodeQuery(stop.originalName, route.routeName);
      final qEncoded = Uri.encodeComponent(query);
      
      try {
        final url = 'https://nominatim.openstreetmap.org/search?q=$qEncoded&format=json&countrycodes=in&viewbox=79.6,13.4,80.4,12.4&bounded=1&limit=3';
        final resp = await http.get(Uri.parse(url), headers: {'User-Agent': 'CollegeBusTrackerImporter/2.0'});
        
        if (resp.statusCode == 200) {
          final list = json.decode(resp.body) as List;
          if (list.isNotEmpty) {
            final candidates = list.map((item) {
              return GeocodeCandidate(
                lat: double.parse(item['lat'].toString()),
                lng: double.parse(item['lon'].toString()),
                address: item['display_name'] ?? '',
                type: item['type'] ?? 'unknown',
                confidence: 0.85,
              );
            }).toList();

            final top = candidates.first;
            if (isInsideBoundingBox(top.lat, top.lng)) {
              // Cache for consistency
              processedLandmarks[normName] = [top.lat, top.lng];
              
              results.add(StopGeocodeResult(
                stop: stop,
                routeNumber: route.routeNumber,
                routeDocId: route.docId,
                lat: top.lat,
                lng: top.lng,
                status: 'ok',
                source: 'osm_nominatim',
                matchedAddress: top.address,
                confidence: top.confidence,
                candidates: candidates,
              ));
            } else {
              results.add(StopGeocodeResult(
                stop: stop,
                routeNumber: route.routeNumber,
                routeDocId: route.docId,
                status: 'needs_review',
                source: 'osm_nominatim',
                flagReason: 'Outside Chennai/TN bounding box',
                candidates: candidates,
              ));
            }
          } else {
            results.add(StopGeocodeResult(
              stop: stop,
              routeNumber: route.routeNumber,
              routeDocId: route.docId,
              status: 'needs_review',
              flagReason: 'No high-precision place found in OSM query',
            ));
          }
        } else {
          results.add(StopGeocodeResult(
            stop: stop,
            routeNumber: route.routeNumber,
            routeDocId: route.docId,
            status: 'needs_review',
            flagReason: 'HTTP error ${resp.statusCode}',
          ));
        }
      } catch (e) {
        results.add(StopGeocodeResult(
          stop: stop,
          routeNumber: route.routeNumber,
          routeDocId: route.docId,
          status: 'needs_review',
          flagReason: 'Geocoding exception: $e',
        ));
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // Route-level sanity checks
  print('\nRunning route-level sanity checks...');
  for (final route in routes) {
    final routeResults = results.where((r) => r.routeDocId == route.docId).toList();
    final isLongDistance = ['4', '34', '37', '39', '42'].contains(route.routeNumber);
    final maxAllowedHop = isLongDistance ? 40000.0 : 15000.0;

    for (int i = 0; i < routeResults.length - 1; i++) {
      final cur = routeResults[i];
      final nxt = routeResults[i + 1];

      if (cur.lat != null && cur.lng != null && nxt.lat != null && nxt.lng != null) {
        final dist = haversineDistance(cur.lat!, cur.lng!, nxt.lat!, nxt.lng!);
        if (dist > maxAllowedHop) {
          cur.status = 'needs_review';
          cur.flagReason = 'Inter-stop jump too large: ${(dist / 1000).toStringAsFixed(1)} km (limit: ${(maxAllowedHop / 1000).toInt()} km)';
        }
      }
    }
  }

  // Count statistics
  int okCount = results.where((r) => r.status == 'ok' || r.status == 'ok_manual').length;
  int needsReviewCount = results.where((r) => r.status == 'needs_review').length;
  int failedCount = results.where((r) => r.status == 'failed').length;

  print('\n=====================================================================');
  print('GEOCODING SUMMARY:');
  print('=====================================================================');
  print('Total Stops Evaluated : ${results.length}');
  print('Status [OK]           : $okCount');
  print('Status [Needs Review] : $needsReviewCount');
  print('Status [Failed]       : $failedCount');
  print('=====================================================================\n');

  // Write geocode_review.csv
  final csvFile = File('geocode_review.csv');
  final csvSink = csvFile.openWrite();
  csvSink.writeln('RouteNumber,RouteDocId,StopIndex,StopName,ScheduledTime,Status,Confidence,Source,FlagReason,Lat,Lng,MatchedAddress,GoogleMapsUrl,Candidate2,Candidate3');

  for (final res in results) {
    final mapsUrl = (res.lat != null && res.lng != null)
        ? 'https://www.google.com/maps?q=${res.lat},${res.lng}'
        : 'N/A';
    
    final c2 = res.candidates.length > 1
        ? '"${res.candidates[1].lat},${res.candidates[1].lng} - ${res.candidates[1].address.replaceAll('"', '""')}"'
        : '';
    final c3 = res.candidates.length > 2
        ? '"${res.candidates[2].lat},${res.candidates[2].lng} - ${res.candidates[2].address.replaceAll('"', '""')}"'
        : '';

    final safeAddress = '"${res.matchedAddress.replaceAll('"', '""')}"';
    final safeReason = '"${res.flagReason.replaceAll('"', '""')}"';

    csvSink.writeln(
      '${res.routeNumber},${res.routeDocId},${res.stop.sequence},"${res.stop.originalName}",${res.stop.scheduledTime24},${res.status},${res.confidence.toStringAsFixed(2)},${res.source},$safeReason,${res.lat ?? ''},${res.lng ?? ''},$safeAddress,$mapsUrl,$c2,$c3',
    );
  }
  await csvSink.flush();
  await csvSink.close();
  print('Wrote review report to: ${csvFile.absolute.path}');

  // Also write all routes JSON artifact for Admin Dashboard review and import
  final exportedRoutes = <Map<String, dynamic>>[];
  for (final route in routes) {
    final routeResults = results.where((r) => r.routeDocId == route.docId).toList();
    final stopsList = <String>[];
    final timesList = <String>[];
    final coordsList = <Map<String, dynamic>>[];

    for (final res in routeResults) {
      stopsList.add(res.stop.originalName);
      timesList.add(res.stop.scheduledTime24);
      coordsList.add({
        'name': res.stop.originalName,
        'lat': res.lat,
        'lng': res.lng,
        'scheduledTime': res.stop.scheduledTime24,
        'status': res.status,
        'source': res.source,
        'confidence': res.confidence,
        'address': res.matchedAddress,
      });
    }

    final allOk = routeResults.every((r) => r.status == 'ok' || r.status == 'ok_manual');

    exportedRoutes.add({
      'routeId': route.docId,
      'routeNumber': route.routeNumber,
      'routeName': route.routeName,
      'shift': route.shift,
      'singleStop': route.singleStop,
      'stops': stopsList,
      'scheduledTimes': timesList,
      'stopCoordinates': coordsList,
      'allStopsOk': allOk,
      'isActive': true,
    });
  }

  final jsonStr = const JsonEncoder.withIndent('  ').convert(exportedRoutes);
  final jsonFile = File('morning_routes_import_data.json');
  await jsonFile.writeAsString(jsonStr);
  print('Wrote exported routes JSON to: ${jsonFile.absolute.path}');

  final jsFile = File('admin_dashboard/js/morning-routes-data.js');
  await jsFile.writeAsString('export const MORNING_ROUTES_DATA = $jsonStr;\n');
  print('Wrote Admin Dashboard routes module to: ${jsFile.absolute.path}\n');
}
