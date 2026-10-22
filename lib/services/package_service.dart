import 'package:supabase_flutter/supabase_flutter.dart';

class PackageService {
  final SupabaseClient _client = Supabase.instance.client;

  // Mengambil semua paket.
  Future<List<Map<String, dynamic>>> getPackages() async {
    final response = await _client
        .from('packages')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Memeriksa apakah pengguna adalah admin.
  Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;

    if (user == null) return false;

    final response = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return response?['role'] == 'admin';
  }

  // Menambahkan paket beserta seluruh informasi tambahannya.
  Future<void> addPackage({
    required String name,
    required String packageType,
    required double price,
    required int durationDays,
    String? description,
    String? facilities,
    String? imageUrl,
    String? airline,
    String? departureDate,
    String? departureCity,
    String? hotelMakkah,
    int? hotelMakkahRating,
    String? hotelMadinah,
    int? hotelMadinahRating,
    double? priceQuad,
    double? priceTriple,
    double? priceDouble,
    String? includedFacilities,
    String? excludedFacilities,
    String? advantages,
  }) async {
    await _client.from('packages').insert({
      'name': name,
      'package_type': packageType,
      'price': price,
      'duration_days': durationDays,
      'description': description,
      'facilities': facilities,
      'image_url': imageUrl,
      'airline': airline,
      'departure_date': departureDate,
      'departure_city': departureCity,
      'hotel_makkah': hotelMakkah,
      'hotel_makkah_rating': hotelMakkahRating,
      'hotel_madinah': hotelMadinah,
      'hotel_madinah_rating': hotelMadinahRating,
      'price_quad': priceQuad,
      'price_triple': priceTriple,
      'price_double': priceDouble,
      'included_facilities': includedFacilities,
      'excluded_facilities': excludedFacilities,
      'advantages': advantages,
    });
  }

  // Mengubah paket beserta seluruh informasi tambahannya.
  Future<void> updatePackage({
    required String id,
    required String name,
    required String packageType,
    required double price,
    required int durationDays,
    String? description,
    String? facilities,
    String? imageUrl,
    String? airline,
    String? departureDate,
    String? departureCity,
    String? hotelMakkah,
    int? hotelMakkahRating,
    String? hotelMadinah,
    int? hotelMadinahRating,
    double? priceQuad,
    double? priceTriple,
    double? priceDouble,
    String? includedFacilities,
    String? excludedFacilities,
    String? advantages,
  }) async {
    await _client
        .from('packages')
        .update({
          'name': name,
          'package_type': packageType,
          'price': price,
          'duration_days': durationDays,
          'description': description,
          'facilities': facilities,
          'image_url': imageUrl,
          'airline': airline,
          'departure_date': departureDate,
          'departure_city': departureCity,
          'hotel_makkah': hotelMakkah,
          'hotel_makkah_rating': hotelMakkahRating,
          'hotel_madinah': hotelMadinah,
          'hotel_madinah_rating': hotelMadinahRating,
          'price_quad': priceQuad,
          'price_triple': priceTriple,
          'price_double': priceDouble,
          'included_facilities': includedFacilities,
          'excluded_facilities': excludedFacilities,
          'advantages': advantages,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  // Menghapus paket.
  Future<void> deletePackage(String id) async {
    await _client.from('packages').delete().eq('id', id);
  }
}
