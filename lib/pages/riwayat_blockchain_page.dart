import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blockchain_service.dart';

class RiwayatBlockchainPage extends StatefulWidget {
  const RiwayatBlockchainPage({super.key});

  @override
  State<RiwayatBlockchainPage> createState() => _RiwayatBlockchainPageState();
}

class _RiwayatBlockchainPageState extends State<RiwayatBlockchainPage> {
  final BlockchainService _service = BlockchainService();

  late Future<List<Map<String, dynamic>>> _vouchersFuture;

  static const Color _green = Color(0xFF176B52);
  static const Color _background = Color(0xFFF6F8F5);
  static const Color _textDark = Color(0xFF20352D);
  static const Color _textMuted = Color(0xFF7A8981);

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    _vouchersFuture = _service.getJamaahVouchers();
  }

  Future<void> _refresh() async {
    setState(_loadVouchers);

    try {
      await _vouchersFuture;
    } catch (_) {
      // Kesalahan ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _downloadVoucher(String code) async {
    try {
      final url = await Supabase.instance.client.storage
          .from('voucher-pdfs')
          .createSignedUrl('$code.pdf', 60);

      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        _showMessage('PDF tidak dapat dibuka.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal membuka PDF. Pastikan file voucher tersedia.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(dynamic value) {
    final timestamp = DateTime.tryParse((value ?? '').toString());

    if (timestamp == null) return '-';

    final date = timestamp.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day $month $year • $hour:$minute';
  }

  String _formatVoucherValue(dynamic value) {
    if (value == null) return '-';

    final amount = double.tryParse(value.toString());
    if (amount == null) return value.toString();

    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0);
    }

    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Voucher Saya',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vouchersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Voucher belum dapat dimuat',
              subtitle: 'Periksa koneksi atau konfigurasi RPC Supabase.',
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            );
          }

          // RPC hanya mengembalikan voucher dengan status active.
          final vouchers = (snapshot.data ?? []).where((voucher) {
            final code = (voucher['voucher_code'] ?? '').toString();

            return code.isNotEmpty &&
                RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code) &&
                (voucher['voucher_status'] ?? '').toString().toLowerCase() ==
                    'active';
          }).toList();

          if (vouchers.isEmpty) {
            return _buildMessage(
              icon: Icons.confirmation_number_outlined,
              title: 'Belum ada voucher aktif',
              subtitle: 'Voucher yang masih berlaku akan muncul di sini.',
              action: OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Muat ulang'),
              ),
            );
          }

          return RefreshIndicator(
            color: _green,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total voucher aktif',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${vouchers.length} voucher',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.white,
                        size: 29,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Daftar voucher',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                ...vouchers.map(_buildVoucherCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
     debugPrint('DATA VOUCHER JAMAAH: $voucher');
     
    final code = (voucher['voucher_code'] ?? '').toString();
    final value = voucher['voucher_value'];
    final currency = (voucher['voucher_currency'] ?? 'SAR')
        .toString()
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F3EC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.airplane_ticket_outlined,
                        color: _green,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KODE VOUCHER',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            code,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F4E9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Terdaftar',
                        style: TextStyle(
                          color: Color(0xFF267346),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F3EC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD2E8DA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          color: _green,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOMINAL VOUCHER',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 10,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$currency ${_formatVoucherValue(value)}',
                              style: const TextStyle(
                                color: _green,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tanggal pendaftaran',
                              style: TextStyle(color: _textMuted, fontSize: 11),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(voucher['created_at']),
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _downloadVoucher(code),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Unduh Voucher PDF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCF9),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Color(0xFFE8EDE8))),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: _green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tercatat dalam sistem blockchain',
                    style: TextStyle(color: _textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F3EC),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _green, size: 35),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}
