import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../services/notification_service.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> package;

  const BookingPage({super.key, required this.package});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bookingService = BookingService();

  DateTime? _departureDate;
  int _participantCount = 1;
  bool _isSubmitting = false;

  static const Color green = Color(0xFF176B50);

  DateTime? get _packageDeparture {
    final raw = DateTime.tryParse(
      widget.package['departure_date']?.toString() ?? '',
    );
    if (raw == null) return null;
    final date = DateTime(raw.year, raw.month, raw.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today) ? null : date;
  }

  @override
  void initState() {
    super.initState();
    // Tanggal berangkat paket dipakai sebagai nilai awal.
    _departureDate = _packageDeparture;
  }

  num get _price =>
      num.tryParse(widget.package['price']?.toString() ?? '') ?? 0;

  String _formatRupiah(num value) {
    final digits = value.toStringAsFixed(0);
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $formatted';
  }

  Future<void> _selectDepartureDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
      helpText: 'Pilih tanggal keberangkatan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (selected != null && mounted) {
      setState(() {
        _departureDate = selected;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal keberangkatan.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Pemesanan'),
        content: Text(
          'Paket: ${widget.package['name']}\n'
          'Pemesan: ${_nameController.text.trim()}\n'
          'Jumlah peserta: $_participantCount orang\n'
          'Total simulasi: ${_formatRupiah(_price * _participantCount)}\n\n'
          'Lanjutkan simulasi pemesanan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Periksa Lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await _bookingService.createBooking(
        package: widget.package,
        departureDate: _departureDate!,
        participantCount: _participantCount,
        originCity: _cityController.text.trim(),
        customerName: _nameController.text.trim(),
      );

      // Pengingat keberangkatan langsung dijadwalkan untuk pemesanan baru.
      try {
        await NotificationService.instance.syncAll();
      } catch (_) {}

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: green, size: 48),
          title: const Text('Pemesanan Berhasil'),
          content: const Text(
            'Simulasi pemesanan berhasil disimpan. '
            'Status pemesanan: Persiapan (preparation).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pemesanan gagal: $error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packageName = widget.package['name']?.toString() ?? 'Paket Umrah';

    final duration = widget.package['duration_days']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Pemesanan'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                packageName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text('Durasi perjalanan: $duration hari'),
              const SizedBox(height: 20),

              const Text(
                'Data Pemesanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama pemesan',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama pemesan wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Kota asal keberangkatan',
                  hintText: 'Contoh: Yogyakarta',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kota asal wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Tanggal Keberangkatan',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _selectDepartureDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _departureDate == null
                        ? 'Pilih tanggal'
                        : '${_departureDate!.day.toString().padLeft(2, '0')}/'
                              '${_departureDate!.month.toString().padLeft(2, '0')}/'
                              '${_departureDate!.year}',
                  ),
                ),
              ),
              if (_packageDeparture != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Paket ini dijadwalkan berangkat '
                  '${_packageDeparture!.day.toString().padLeft(2, '0')}/'
                  '${_packageDeparture!.month.toString().padLeft(2, '0')}/'
                  '${_packageDeparture!.year}. Kamu bisa menggantinya.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),

              const Text(
                'Jumlah Peserta',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                value: _participantCount,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: List.generate(
                  10,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1} orang'),
                  ),
                ),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _participantCount = value);
                        }
                      },
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan Biaya Simulasi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Harga per peserta'),
                          Text(_formatRupiah(_price)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Jumlah peserta'),
                          Text('$_participantCount orang'),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Total simulasi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            _formatRupiah(_price * _participantCount),
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Harga ini merupakan simulasi berdasarkan data paket. '
                'Pemesanan belum merupakan transaksi atau pembayaran '
                'perjalanan yang sebenarnya.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting
                        ? 'Menyimpan Pemesanan...'
                        : 'Konfirmasi Pemesanan',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
