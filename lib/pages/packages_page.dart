import 'package:flutter/material.dart';

import '../services/package_service.dart';
import 'package_detail_page.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  final PackageService _service = PackageService();

  late Future<List<Map<String, dynamic>>> _packagesFuture;

  static const Color green = Color(0xFF176B50);

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  void _loadPackages() {
    _packagesFuture = _service.getPackages();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadPackages();
    });

    try {
      await _packagesFuture;
    } catch (_) {
      // Error ditampilkan oleh FutureBuilder.
    }
  }

  String _formatPrice(dynamic value) {
    final price = num.tryParse(value?.toString() ?? '') ?? 0;
    final digits = price.toStringAsFixed(0);

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String _formatType(String type) {
    switch (type) {
      case 'umrah_reguler':
        return 'Umrah Reguler';
      case 'umrah_plus_turki':
        return 'Umrah Plus Turki';
      default:
        return type.isNotEmpty ? type : 'Paket Umrah';
    }
  }

  void _openPackageDetail(Map<String, dynamic> package) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageDetailPage(package: package),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket Perjalanan'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _packagesFuture,
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
                    const Icon(Icons.cloud_off, size: 48, color: green),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat paket dari Supabase.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loadPackages();
                        });
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.luggage_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('Belum ada paket perjalanan.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];

                final name = package['name']?.toString() ?? 'Paket Umrah';

                final type = _formatType(
                  package['package_type']?.toString() ?? '',
                );

                final duration = package['duration_days']?.toString() ?? '-';

                final description = package['description']?.toString() ?? '';

                final facilities = package['facilities']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openPackageDetail(package),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.flight_takeoff_rounded,
                                size: 36,
                                color: green,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Chip(
                            label: Text(type),
                            backgroundColor: green.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text('$duration hari'),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _formatPrice(package['price']),
                            style: const TextStyle(
                              color: green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          if (facilities.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Fasilitas: $facilities',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          const Text(
                            'Ketuk untuk melihat detail paket',
                            style: TextStyle(
                              color: green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
}
