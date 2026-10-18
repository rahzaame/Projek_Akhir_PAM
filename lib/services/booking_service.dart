import 'package:supabase_flutter/supabase_flutter.dart';

class BookingService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createBooking({
    required Map<String, dynamic> package,
    required DateTime departureDate,
    required int participantCount,
    required String originCity,
    required String customerName,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    final packageId = package['id'];
    if (packageId == null) {
      throw Exception('ID paket tidak ditemukan.');
    }

    final price = num.tryParse(package['price']?.toString() ?? '') ?? 0;

    final duration =
        int.tryParse(package['duration_days']?.toString() ?? '') ?? 0;

    if (duration <= 0) {
      throw Exception('Durasi paket tidak valid.');
    }

    if (participantCount <= 0) {
      throw Exception('Jumlah peserta harus lebih dari 0.');
    }

    final returnDate = departureDate.add(Duration(days: duration));

    await _client.from('trips').insert({
      'user_id': user.id,
      'trip_name': package['name'],
      'trip_type': 'umrah',
      'departure_date': departureDate.toIso8601String().split('T').first,
      'return_date': returnDate.toIso8601String().split('T').first,
      'origin_city': originCity.trim(),
      'status': 'preparation',
      'package_id': packageId,
      'participant_count': participantCount,
      'total_amount': price * participantCount,
      'customer_name': customerName.trim(),
    });
  }
}
