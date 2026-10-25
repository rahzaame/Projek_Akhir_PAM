import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/format_utils.dart';

class TripService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    return user.id;
  }

  static const List<String> statuses = [
    'preparation',
    'ongoing',
    'completed',
    'cancelled',
  ];

  static String statusLabel(String? status) {
    switch (status) {
      case 'preparation':
        return 'Persiapan';
      case 'ongoing':
        return 'Sedang berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status == null || status.isEmpty ? '-' : status;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyTrips() async {
    final response = await _client
        .from('trips')
        .select()
        .eq('user_id', _userId)
        .order('departure_date', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .where((t) => t['status'] != 'cancelled')
        .toList();
  }

  Future<Map<String, dynamic>?> fetchFeaturedTrip() async {
    final trips = await fetchMyTrips();
    if (trips.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final t in trips) {
      if (t['status'] == 'ongoing') return t;
    }

    for (final t in trips) {
      if (t['status'] == 'completed') continue;
      final dep = parseDbDate(t['departure_date']);
      if (dep != null && !dep.isBefore(today)) return t;
    }

    return trips.last;
  }

  Future<List<Map<String, dynamic>>> fetchAllTrips() async {
    final response = await _client
        .from('trips')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateStatus(String tripId, String status) async {
    final rows = await _client
        .from('trips')
        .update({'status': status})
        .eq('id', tripId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw Exception(
        'Status tidak berubah. Pastikan akun ini admin dan kebijakan '
        'database sudah dijalankan.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchVoucherLinks(String tripId) async {
    final response = await _client
        .from('voucher_links')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> countMyVouchers() async {
    final response = await _client
        .from('voucher_links')
        .select('id')
        .eq('user_id', _userId);
    return (response as List).length;
  }

  Future<void> linkVoucher({
    required String voucherCode,
    required Map<String, dynamic> trip,
  }) async {
    await _client.from('voucher_links').upsert({
      'voucher_code': voucherCode.trim(),
      'trip_id': trip['id'],
      'user_id': trip['user_id'],
    }, onConflict: 'voucher_code');
  }

  Future<bool> openVoucherPdf(String code) async {
    final url = await _client.storage
        .from('voucher-pdfs')
        .createSignedUrl('$code.pdf', 60);
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
