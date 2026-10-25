import 'package:flutter/material.dart';

import '../services/itinerary_service.dart';
import 'peta_lokasi_page.dart' show PetaLokasiPage;

class ItineraryPage extends StatefulWidget {
  final Map<String, dynamic>? package;

  const ItineraryPage({super.key, this.package});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  static const Color green = Color(0xFF176B50);

  final ItineraryService _itineraryService = ItineraryService();

  late Future<List<Map<String, dynamic>>> _itineraryFuture;

  @override
  void initState() {
    super.initState();
    _loadItinerary();
  }

  void _loadItinerary() {
    final packageId = widget.package?['id']?.toString();

    if (packageId == null || packageId.isEmpty) {
      _itineraryFuture = Future.value([]);
    } else {
      _itineraryFuture = _itineraryService.getItinerary(packageId);
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final time = value.toString();
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.package?['name']?.toString() ?? 'Jadwal Perjalanan';

    final type = widget.package?['package_type']?.toString() ?? '';

    final duration = widget.package?['duration_days']?.toString() ?? '-';

    final packageType = type == 'umrah_plus_turki'
        ? 'Umrah Plus Turki'
        : 'Umrah Reguler';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinerary Perjalanan'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itineraryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Jadwal gagal dimuat',
              description:
                  'Periksa koneksi internet dan konfigurasi Supabase, '
                  'lalu coba kembali.',
              showRetry: true,
            );
          }

          final schedule = snapshot.data ?? [];

          if (widget.package == null) {
            return _buildMessage(
              icon: Icons.calendar_month_outlined,
              title: 'Pilih paket perjalanan',
              description:
                  'Buka menu Paket Umrah, pilih paket yang kamu inginkan, '
                  'lalu tekan Lihat Itinerary untuk melihat jadwalnya.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F2E8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.calendar_month, color: green, size: 34),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: green,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$packageType • $duration hari'),
                    const SizedBox(height: 10),
                    const Text(
                      'Jadwal kegiatan berdasarkan data paket '
                      'yang tersimpan di SafarMate.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Jadwal Kegiatan',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (schedule.isEmpty)
                _buildMessage(
                  icon: Icons.event_busy_outlined,
                  title: 'Itinerary belum tersedia',
                  description:
                      'Belum ada jadwal yang ditambahkan untuk paket ini. '
                      'Admin perlu mengisi itinerary paket terlebih dahulu.',
                )
              else
                ...schedule.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  final day = item['day_number']?.toString() ?? '-';
                  final title = item['title']?.toString() ?? 'Kegiatan';
                  final description = item['description']?.toString() ?? '';
                  final location = item['location']?.toString() ?? '';
                  final startTime = _formatTime(item['start_time']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE1F2E8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.event_note,
                                color: green,
                                size: 22,
                              ),
                            ),
                            if (index < schedule.length - 1)
                              Container(
                                width: 2,
                                height: 55,
                                color: const Color(0xFFD6E7DC),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hari $day',
                                    style: const TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      style: const TextStyle(height: 1.4),
                                    ),
                                  ],
                                  if (location.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: green,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(child: Text(location)),
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PetaLokasiPage(
                                                initialQuery: location,
                                              ),
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text('Lihat di peta'),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (startTime.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 18,
                                          color: green,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(startTime),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String description,
    bool showRetry = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: green),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            if (showRetry) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loadItinerary();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
