import 'package:supabase_flutter/supabase_flutter.dart';

class ItineraryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getItinerary(String packageId) async {
    final response = await _supabase
        .from('itinerary_items')
        .select()
        .eq('package_id', packageId)
        .order('day_number', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addItinerary({
    required String packageId,
    required int dayNumber,
    required String title,
    String? description,
    String? location,
    String? startTime,
  }) async {
    await _supabase.from('itinerary_items').insert({
      'package_id': packageId,
      'day_number': dayNumber,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime,
    });
  }

  Future<void> updateItinerary({
    required String id,
    required int dayNumber,
    required String title,
    String? description,
    String? location,
    String? startTime,
  }) async {
    await _supabase
        .from('itinerary_items')
        .update({
          'day_number': dayNumber,
          'title': title,
          'description': description,
          'location': location,
          'start_time': startTime,
        })
        .eq('id', id);
  }

  Future<void> deleteItinerary(String id) async {
    await _supabase.from('itinerary_items').delete().eq('id', id);
  }
}
