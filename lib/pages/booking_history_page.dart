import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'booking_detail_page.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final SupabaseClient _client = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _historyFuture;

  static const Color green = Color(0xFF176B50);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    final response = await _client
        .from('trips')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _refresh() async {
    setState(_loadHistory);

    try {
      await _historyFuture;
    } catch (_) {
      // Pesan error ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _openBookingDetail(Map<String, dynamic> booking) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailPage(booking: booking)),
    );

    if (!mounted) return;

    await _fetchHistory();
  }

  String _formatRupiah(dynamic value) {
    final amount = num.tryParse(value?.toString() ?? '') ?? 0;
    final digits = amount.toStringAsFixed(0);

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'preparation':
        return 'Persiapan';
      case 'ongoing':
        return 'Sedang Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status ?? 'Tidak diketahui';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'preparation':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pemesanan'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat riwayat pemesanan.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(_loadHistory);
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  Icon(Icons.luggage_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(child: Text('Belum ada riwayat pemesanan.')),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Pemesanan paketmu akan muncul di sini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];

                final status = booking['status']?.toString();

                final tripName =
                    booking['trip_name']?.toString() ?? 'Paket Umrah';

                final participantCount =
                    booking['participant_count']?.toString() ?? '1';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openBookingDetail(booking),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.flight_takeoff_rounded,
                                color: green,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tripName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatStatus(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          const Divider(height: 24),

                          _infoRow(
                            Icons.calendar_month_outlined,
                            'Keberangkatan',
                            _formatDate(booking['departure_date']),
                          ),

                          const SizedBox(height: 10),

                          _infoRow(
                            Icons.event_available_outlined,
                            'Tanggal kembali',
                            _formatDate(booking['return_date']),
                          ),

                          const SizedBox(height: 10),

                          _infoRow(
                            Icons.groups_outlined,
                            'Jumlah peserta',
                            '$participantCount orang',
                          ),

                          const SizedBox(height: 10),

                          _infoRow(
                            Icons.location_on_outlined,
                            'Kota asal',
                            booking['origin_city']?.toString() ?? '-',
                          ),

                          const Divider(height: 24),

                          const Text(
                            'Total biaya simulasi',
                            style: TextStyle(fontSize: 13),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            _formatRupiah(booking['total_amount']),
                            style: const TextStyle(
                              color: green,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Ketuk untuk melihat detail',
                              style: TextStyle(
                                color: green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
