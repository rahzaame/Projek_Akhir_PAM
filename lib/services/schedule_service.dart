import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/format_utils.dart';

class ScheduleService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    final response = await _client
        .from('schedules')
        .select()
        .eq('user_id', _userId)
        .order('schedule_date', ascending: true)
        .order('start_time', ascending: true, nullsFirst: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addSchedule({
    required String title,
    required DateTime date,
    required String timezone,
    int? hour,
    int? minute,
    String? description,
    String? location,
    int? reminderMinutes,
    String? tripId,
  }) async {
    final row = await _client
        .from('schedules')
        .insert({
          'user_id': _userId,
          'trip_id': tripId,
          'title': title.trim(),
          'description': _nullIfEmpty(description),
          'location': _nullIfEmpty(location),
          'schedule_date': toDbDate(date),
          'start_time': (hour != null && minute != null)
              ? toDbTime(hour, minute)
              : null,
          'timezone': timezone,
          'reminder_minutes': reminderMinutes,
          'source': 'manual',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateSchedule({
    required String id,
    required String title,
    required DateTime date,
    required String timezone,
    int? hour,
    int? minute,
    String? description,
    String? location,
    int? reminderMinutes,
  }) async {
    final row = await _client
        .from('schedules')
        .update({
          'title': title.trim(),
          'description': _nullIfEmpty(description),
          'location': _nullIfEmpty(location),
          'schedule_date': toDbDate(date),
          'start_time': (hour != null && minute != null)
              ? toDbTime(hour, minute)
              : null,
          'timezone': timezone,
          'reminder_minutes': reminderMinutes,
        })
        .eq('id', id)
        .eq('user_id', _userId)
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  Future<void> deleteSchedule(String id) async {
    await _client
        .from('schedules')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<List<Map<String, dynamic>>> fetchTrips() async {
    final response = await _client
        .from('trips')
        .select(
          'id, trip_name, departure_date, return_date, package_id, status',
        )
        .eq('user_id', _userId)
        .order('departure_date', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .where((trip) => trip['status'] != 'cancelled')
        .toList();
  }

  Future<List<Map<String, dynamic>>> importItinerary({
    required Map<String, dynamic> trip,
    required String timezone,
    int reminderMinutes = 60,
  }) async {
    final packageId = trip['package_id']?.toString();
    if (packageId == null || packageId.isEmpty) {
      throw Exception('Pemesanan ini belum terhubung dengan paket.');
    }

    final departure = parseDbDate(trip['departure_date']);
    if (departure == null) {
      throw Exception('Tanggal keberangkatan tidak valid.');
    }

    final tripId = trip['id'].toString();

    final items = List<Map<String, dynamic>>.from(
      await _client
          .from('itinerary_items')
          .select()
          .eq('package_id', packageId)
          .order('day_number', ascending: true),
    );

    if (items.isEmpty) {
      throw Exception('Itinerary paket ini belum diisi oleh admin.');
    }

    final existing = List<Map<String, dynamic>>.from(
      await _client
          .from('schedules')
          .select('itinerary_item_id')
          .eq('user_id', _userId)
          .eq('trip_id', tripId)
          .not('itinerary_item_id', 'is', null),
    ).map((row) => row['itinerary_item_id'].toString()).toSet();

    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final itemId = item['id'].toString();
      if (existing.contains(itemId)) continue;

      final day = int.tryParse(item['day_number']?.toString() ?? '') ?? 1;
      final date = departure.add(Duration(days: day < 1 ? 0 : day - 1));
      final time = parseDbTime(item['start_time']);

      rows.add({
        'user_id': _userId,
        'trip_id': tripId,
        'itinerary_item_id': itemId,
        'title': item['title']?.toString() ?? 'Kegiatan',
        'description': _nullIfEmpty(item['description']?.toString()),
        'location': _nullIfEmpty(item['location']?.toString()),
        'schedule_date': toDbDate(date),
        'start_time': time != null ? toDbTime(time.hour, time.minute) : null,
        'timezone': timezone,
        'reminder_minutes': time != null ? reminderMinutes : null,
        'source': 'itinerary',
      });
    }

    if (rows.isEmpty) return [];

    final inserted = await _client.from('schedules').insert(rows).select();
    return List<Map<String, dynamic>>.from(inserted);
  }

  Future<List<String>> deleteSchedulesForTrip(String tripId) async {
    final rows = await _client
        .from('schedules')
        .delete()
        .eq('user_id', _userId)
        .eq('trip_id', tripId)
        .select('id');
    return List<Map<String, dynamic>>.from(rows)
        .map((r) => r['id'].toString())
        .toList();
  }

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
