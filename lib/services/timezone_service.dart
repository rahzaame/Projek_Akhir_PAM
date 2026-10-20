import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class TravelZone {
  final String code;
  final String name;
  final String tzId;
  final String note;

  const TravelZone({
    required this.code,
    required this.name,
    required this.tzId,
    required this.note,
  });
}

class ZoneTime {
  final TravelZone zone;
  final tz.TZDateTime time;
  final int dayDifference;

  const ZoneTime({
    required this.zone,
    required this.time,
    required this.dayDifference,
  });

  String get utcLabel {
    final offset = time.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? 'UTC$sign$h' : 'UTC$sign$h:${m.toString().padLeft(2, '0')}';
  }
}

class TimezoneService {
  TimezoneService._();

  static bool _initialized = false;

  /// Aman dipanggil berkali-kali.
  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static const List<TravelZone> zones = [
    TravelZone(
      code: 'WIB',
      name: 'Waktu Indonesia Barat',
      tzId: 'Asia/Jakarta',
      note: 'Jakarta, Purwokerto',
    ),
    TravelZone(
      code: 'WITA',
      name: 'Waktu Indonesia Tengah',
      tzId: 'Asia/Makassar',
      note: 'Makassar, Bali',
    ),
    TravelZone(
      code: 'WIT',
      name: 'Waktu Indonesia Timur',
      tzId: 'Asia/Jayapura',
      note: 'Jayapura, Ambon',
    ),
    TravelZone(
      code: 'London',
      name: 'London (GMT/BST)',
      tzId: 'Europe/London',
      note: 'Inggris',
    ),
    TravelZone(
      code: 'Arab Saudi',
      name: 'Arab Saudi (AST)',
      tzId: 'Asia/Riyadh',
      note: 'Makkah, Madinah',
    ),
    TravelZone(
      code: 'Turki',
      name: 'Turki (TRT)',
      tzId: 'Europe/Istanbul',
      note: 'Istanbul',
    ),
  ];

  static TravelZone zoneById(String tzId) {
    return zones.firstWhere((z) => z.tzId == tzId, orElse: () => zones.first);
  }

  static tz.Location location(String tzId) {
    ensureInitialized();
    return tz.getLocation(tzId);
  }

  static tz.TZDateTime nowIn(String tzId) {
    ensureInitialized();
    return tz.TZDateTime.now(location(tzId));
  }

  static tz.TZDateTime wallTime(
    String tzId,
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    return tz.TZDateTime(location(tzId), year, month, day, hour, minute);
  }

  static List<ZoneTime> convertToAll(tz.TZDateTime source) {
    ensureInitialized();
    final sourceDay = DateTime.utc(source.year, source.month, source.day);

    return zones.map((zone) {
      final converted = tz.TZDateTime.from(source, location(zone.tzId));
      final convertedDay = DateTime.utc(
        converted.year,
        converted.month,
        converted.day,
      );
      return ZoneTime(
        zone: zone,
        time: converted,
        dayDifference: convertedDay.difference(sourceDay).inDays,
      );
    }).toList();
  }

  static tz.TZDateTime convert(tz.TZDateTime source, String targetTzId) {
    ensureInitialized();
    return tz.TZDateTime.from(source, location(targetTzId));
  }
}
