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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _packagesFuture;

  static const Color green = Color(0xFF176B50);
  static const Color background = Color(0xFFF7F8F6);
  static const Color lightGreen = Color(0xFFEAF4EF);

  String _searchQuery = '';
  int? _selectedDuration;
  String? _selectedDepartureMonth;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _loadPackages() {
    _packagesFuture = _service.getPackages();
  }

  Future<void> _refresh() async {
    setState(_loadPackages);
    try {
      await _packagesFuture;
    } catch (_) {}
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

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Tanggal belum tersedia';
    }

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    final year = parts[0];

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

    return '${months[month - 1]} $year';
  }

  Map<String, String> _getDepartureMonths(List<Map<String, dynamic>> packages) {
    final result = <String, String>{};

    for (final package in packages) {
      final rawDate = package['departure_date']?.toString();
      if (rawDate == null || rawDate.isEmpty) continue;

      final date = DateTime.tryParse(rawDate);
      if (date == null) continue;

      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      result[key] = _monthLabel(key);
    }

    final keys = result.keys.toList()..sort();

    return {for (final key in keys) key: result[key]!};
  }

  int? _parsePrice(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  bool get _hasActiveFilters =>
      _selectedDuration != null ||
      _selectedDepartureMonth != null ||
      _minPriceController.text.isNotEmpty ||
      _maxPriceController.text.isNotEmpty;

  List<Map<String, dynamic>> _filterPackages(
    List<Map<String, dynamic>> packages,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final minPrice = _parsePrice(_minPriceController.text);
    final maxPrice = _parsePrice(_maxPriceController.text);

    return packages.where((package) {
      final searchableText = [
        package['name'],
        package['package_type'],
        package['description'],
        package['facilities'],
        package['airline'],
        package['departure_city'],
        package['hotel_makkah'],
        package['hotel_madinah'],
        package['advantages'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();

      if (query.isNotEmpty && !searchableText.contains(query)) {
        return false;
      }

      final duration = int.tryParse(package['duration_days']?.toString() ?? '');

      if (_selectedDuration != null && duration != _selectedDuration) {
        return false;
      }

      if (_selectedDepartureMonth != null) {
        final date = DateTime.tryParse(
          package['departure_date']?.toString() ?? '',
        );

        if (date == null) return false;

        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

        if (key != _selectedDepartureMonth) return false;
      }

      final price = num.tryParse(package['price']?.toString() ?? '');
      if (price == null) return false;
      if (minPrice != null && price < minPrice) return false;
      if (maxPrice != null && price > maxPrice) return false;

      return true;
    }).toList();
  }

  void _resetFilters({bool refresh = true}) {
    void reset() {
      _selectedDuration = null;
      _selectedDepartureMonth = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    }

    if (refresh) {
      setState(reset);
    } else {
      reset();
    }
  }

  Future<void> _openFilterSheet(List<Map<String, dynamic>> packages) async {
    int? tempDuration = _selectedDuration;
    String? tempMonth = _selectedDepartureMonth;

    final tempMinController = TextEditingController(
      text: _minPriceController.text,
    );
    final tempMaxController = TextEditingController(
      text: _maxPriceController.text,
    );

    final durations =
        packages
            .map((p) => int.tryParse(p['duration_days']?.toString() ?? ''))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();

    final months = _getDepartureMonths(packages);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: green),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Filter Paket',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempDuration = null;
                                tempMonth = null;
                                tempMinController.clear();
                                tempMaxController.clear();
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Durasi perjalanan',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        value: tempDuration,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.calendar_month_outlined,
                            color: green,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Semua durasi'),
                          ),
                          ...durations.map(
                            (duration) => DropdownMenuItem<int?>(
                              value: duration,
                              child: Text('$duration hari'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => tempDuration = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Bulan keberangkatan',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: tempMonth,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.flight_takeoff_rounded,
                            color: green,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua bulan'),
                          ),
                          ...months.entries.map(
                            (entry) => DropdownMenuItem<String?>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() => tempMonth = value);
                        },
                      ),
                      if (months.isEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Tanggal keberangkatan belum tersedia.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Rentang harga (Rp)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tempMinController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Minimum',
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('—'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: tempMaxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Maksimum',
                                prefixText: 'Rp ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  tempDuration = null;
                                  tempMonth = null;
                                  tempMinController.clear();
                                  tempMaxController.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(color: green),
                              ),
                              child: const Text('Reset filter'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDuration = tempDuration;
                                  _selectedDepartureMonth = tempMonth;

                                  _minPriceController.text =
                                      tempMinController.text;
                                  _maxPriceController.text =
                                      tempMaxController.text;
                                });

                                Navigator.pop(sheetContext);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Terapkan'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    tempMinController.dispose();
    tempMaxController.dispose();
  }

  void _openPackageDetail(Map<String, dynamic> package) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PackageDetailPage(package: package)),
    );
  }

  Widget _buildSearchBar(List<Map<String, dynamic>> packages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Cari paket, hotel, maskapai...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: green),
                prefixIconConstraints: const BoxConstraints(minWidth: 42),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: _hasActiveFilters ? green : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openFilterSheet(packages),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasActiveFilters ? green : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _hasActiveFilters ? Colors.white : green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: _hasActiveFilters ? Colors.white : green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.circle, size: 7, color: Colors.white),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageImage(Map<String, dynamic> package) {
    final imageUrl = package['image_url']?.toString().trim() ?? '';

    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 175,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF176B50), Color(0xFF4C987B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -25,
            child: Icon(
              Icons.mosque_rounded,
              size: 170,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          const Positioned(
            left: 18,
            bottom: 20,
            child: Row(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAFARMATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Perjalanan Ibadah Anda',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: green, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final name = package['name']?.toString() ?? 'Paket Umrah';
    final type = _formatType(package['package_type']?.toString() ?? '');
    final duration = package['duration_days']?.toString() ?? '-';
    final airline = package['airline']?.toString() ?? '';
    final date = package['departure_date'];
    final advantages = package['advantages']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openPackageDetail(package),
        child: SizedBox(
          height: 224,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gambar paket di sebelah kiri.
              SizedBox(
                width: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPackageImage(package),
                    Positioned(
                      left: 7,
                      right: 7,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          type,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$duration Hari',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Informasi paket di sebelah kanan.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (airline.isNotEmpty) ...[
                        _buildInfoItem(Icons.flight_rounded, airline),
                        const SizedBox(height: 6),
                      ],

                      _buildInfoItem(
                        Icons.calendar_month_outlined,
                        _formatDate(date),
                      ),

                      if (advantages.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          advantages,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                            height: 1.25,
                          ),
                        ),
                      ],

                      // Harga diletakkan lebih dekat dengan deskripsi.
                      const SizedBox(height: 8),
                      Text(
                        'Mulai dari',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(package['price']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      // Tombol lebih kecil dan rata kanan.
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          height: 29,
                          child: FilledButton(
                            onPressed: () => _openPackageDetail(package),
                            style: FilledButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 29),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lihat Detail',
                                  style: TextStyle(fontSize: 11),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 13),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 50),
        Icon(Icons.search_off_rounded, size: 62, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Paket tidak ditemukan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Coba ubah kata kunci atau pilihan filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Paket Perjalanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _packagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: green));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 50, color: green),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat paket dari Supabase.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(_loadPackages),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final packages = snapshot.data ?? [];
          final filtered = _filterPackages(packages);

          return Column(
            children: [
              _buildSearchBar(packages),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilihan Paket Umrah',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length} paket',
                      style: const TextStyle(
                        color: green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: filtered.isEmpty
                      ? _buildEmptyResults()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildPackageCard(filtered[index]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
