import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/blockchain_service.dart';

class AdminVoucherListPage extends StatefulWidget {
  const AdminVoucherListPage({super.key});

  @override
  State<AdminVoucherListPage> createState() => _AdminVoucherListPageState();
}

class _AdminVoucherListPageState extends State<AdminVoucherListPage> {
  final BlockchainService _service = BlockchainService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _futureVouchers;

  static const Color _green = Color(0xFF287653);
  static const Color _background = Color(0xFFF6F8F5);

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    _futureVouchers = _service.getVouchers();
  }

  Future<void> _refresh() async {
    setState(_loadVouchers);

    try {
      await _futureVouchers;
    } catch (_) {
      // Error ditampilkan oleh FutureBuilder.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPdf(String code) async {
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
        _message('PDF gagal dibuka.');
      }
    } catch (e) {
      _message('Gagal membuka PDF: $e');
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '-';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Daftar Voucher',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari kode voucher...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureVouchers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                if (snapshot.hasError) {
                  return _emptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Gagal memuat voucher',
                    subtitle: 'Periksa koneksi, lalu coba muat ulang.',
                    action: OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  );
                }

                final query = _searchController.text.trim().toLowerCase();

                final vouchers = (snapshot.data ?? []).where((voucher) {
                  final code = (voucher['voucher_code'] ?? '').toString();

                  return code.toLowerCase().contains(query);
                }).toList();

                if (vouchers.isEmpty) {
                  return _emptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Belum ada voucher',
                    subtitle: query.isEmpty
                        ? 'Voucher yang terdaftar akan muncul di sini.'
                        : 'Tidak ada voucher yang cocok dengan pencarian.',
                  );
                }

                return RefreshIndicator(
                  color: _green,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              color: Colors.white,
                              size: 34,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Voucher Terdaftar',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${vouchers.length} voucher',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...vouchers.map(_buildVoucherCard),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final code = (voucher['voucher_code'] ?? '').toString();
    final value = voucher['voucher_value'];
    final status = (voucher['voucher_status'] ?? 'unknown').toString();

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5EAE5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.airplane_ticket_outlined,
                    color: _green,
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
                          fontSize: 10,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        code.isEmpty ? 'Tanpa kode' : code,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_outlined, color: _green),
              ],
            ),
            const Divider(height: 26),
            _infoRow(Icons.payments_outlined, 'Nominal', 'SAR ${value ?? '-'}'),
            const SizedBox(height: 12),
            _infoRow(
              Icons.tag,
              'Nomor blok',
              '${voucher['block_index'] ?? '-'}',
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.calendar_today_outlined,
              'Tanggal terdaftar',
              _formatDate(voucher['created_at']),
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.info_outline, 'Status', status),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: code.isEmpty ? null : () => _openPdf(code),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Lihat / Unduh PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: _green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
