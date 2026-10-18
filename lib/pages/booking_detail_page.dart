import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailPage({super.key, required this.booking});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isCancelling = false;
  late String _status;

  static const Color safarGreen = Color(0xFF176B50);
  static const Color safarLightGreen = Color(0xFFE1F2E8);

  @override
  void initState() {
    super.initState();
    _status = widget.booking['status']?.toString() ?? '';
  }

  String _formatRupiah(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    final formatted = number.toStringAsFixed(0);
    final result = StringBuffer();

    for (int i = 0; i < formatted.length; i++) {
      result.write(formatted[i]);

      final remaining = formatted.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        result.write('.');
      }
    }

    return 'Rp${result.toString()}';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatStatus(String status) {
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
        return status.isEmpty ? '-' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'preparation':
        return Colors.orange;
      case 'ongoing':
        return Colors.blue;
      case 'completed':
        return safarGreen;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Pemesanan?'),
          content: const Text(
            'Apakah kamu yakin ingin membatalkan pemesanan ini? '
            'Status pemesanan akan berubah menjadi Dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Tidak'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Ya, Batalkan'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final user = _client.auth.currentUser;
    final bookingId = widget.booking['id'];

    if (user == null || bookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data pengguna atau pemesanan tidak ditemukan.'),
        ),
      );
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final response = await _client
          .from('trips')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .eq('status', 'preparation')
          .select('id');

      if (response.isEmpty) {
        throw Exception(
          'Pemesanan tidak dapat dibatalkan. '
          'Pastikan statusnya masih Persiapan.',
        );
      }

      if (!mounted) return;

      setState(() {
        _status = 'cancelled';
        widget.booking['status'] = 'cancelled';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemesanan berhasil dibatalkan.'),
          backgroundColor: safarGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan pemesanan: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: safarGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packageName =
        widget.booking['trip_name']?.toString() ?? 'Paket Umrah';

    final customerName = widget.booking['customer_name']?.toString() ?? '-';

    final originCity = widget.booking['origin_city']?.toString() ?? '-';

    final participantCount =
        widget.booking['participant_count']?.toString() ?? '1';

    final totalAmount = _formatRupiah(widget.booking['total_amount']);

    final canCancel =
        widget.booking['package_id'] != null && _status == 'preparation';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pemesanan'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: safarLightGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mosque_rounded, size: 38, color: safarGreen),
                  const SizedBox(height: 12),
                  Text(
                    packageName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: safarGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(_status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(_status),
                      style: TextStyle(
                        color: _statusColor(_status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Informasi Pemesanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _detailRow(Icons.person_outline, 'Nama Pemesan', customerName),
            _detailRow(
              Icons.calendar_month_outlined,
              'Tanggal Keberangkatan',
              _formatDate(widget.booking['departure_date']),
            ),
            _detailRow(
              Icons.event_available_outlined,
              'Tanggal Kepulangan',
              _formatDate(widget.booking['return_date']),
            ),
            _detailRow(
              Icons.groups_outlined,
              'Jumlah Peserta',
              '$participantCount orang',
            ),
            _detailRow(
              Icons.location_on_outlined,
              'Kota Keberangkatan',
              originCity,
            ),
            _detailRow(
              Icons.payments_outlined,
              'Total Pemesanan (Simulasi)',
              totalAmount,
            ),
            const SizedBox(height: 24),
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelBooking,
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _isCancelling ? 'Membatalkan...' : 'Batalkan Pemesanan',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            if (_status == 'cancelled')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pemesanan ini sudah dibatalkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Kembali ke Riwayat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: safarGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
