import 'package:flutter/material.dart';

import 'booking_page.dart';
import 'itinerary_page.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class PackageDetailPage extends StatelessWidget {
  final Map<String, dynamic> package;

  const PackageDetailPage({super.key, required this.package});

  String formatRupiah(dynamic value) {
    final price = num.tryParse(value?.toString() ?? '');

    if (price == null) return '-';

    final formatted = price.toStringAsFixed(0);
    final result = formatted.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $result';
  }

  String formatType(String type) {
    switch (type) {
      case 'umrah_reguler':
        return 'Umrah Reguler';
      case 'umrah_plus_turki':
        return 'Umrah Plus Turki';
      default:
        return type.isNotEmpty ? type : 'Paket Umrah';
    }
  }

  String formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';

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

  List<String> parseList(String? value) {
    if (value == null || value.trim().isEmpty) return [];

    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = package['name']?.toString() ?? 'Paket Umrah';
    final type = package['package_type']?.toString() ?? '';
    final duration = package['duration_days']?.toString() ?? '-';
    final description = package['description']?.toString() ?? '';
    final imageUrl = package['image_url']?.toString() ?? '';

    final airline = package['airline']?.toString() ?? '';
    final departureDate = formatDate(package['departure_date']);
    final departureCity = package['departure_city']?.toString() ?? '';

    final hotelMakkah = package['hotel_makkah']?.toString() ?? '';
    final hotelMadinah = package['hotel_madinah']?.toString() ?? '';

    final makkahRating = package['hotel_makkah_rating'];
    final madinahRating = package['hotel_madinah_rating'];

    final included = parseList(package['included_facilities']?.toString());
    final excluded = parseList(package['excluded_facilities']?.toString());
    final advantages = parseList(package['advantages']?.toString());

    final facilities = parseList(package['facilities']?.toString());

    // Harga kamar yang belum diisi tidak ditampilkan.
    final roomPrices = <MapEntry<String, dynamic>>[
      MapEntry('Quad (4 orang/kamar)', package['price_quad']),
      MapEntry('Triple (3 orang/kamar)', package['price_triple']),
      MapEntry('Double (2 orang/kamar)', package['price_double']),
    ].where((entry) => entry.value != null).toList();

    // Gunakan harga kamar Quad sebagai harga awal jika tersedia.
    final startingPrice = package['price_quad'] ?? package['price'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Paket'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar paket
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                else
                  _imagePlaceholder(),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama dan tipe paket
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: safarLightGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          formatType(type),
                          style: const TextStyle(
                            color: safarGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Informasi durasi dan maskapai
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _infoItem(
                              Icons.calendar_month_outlined,
                              'Durasi',
                              '$duration hari',
                            ),
                          ),
                          Expanded(
                            child: _infoItem(
                              Icons.flight_outlined,
                              'Maskapai',
                              airline.isNotEmpty ? airline : 'Belum tersedia',
                            ),
                          ),
                        ],
                      ),

                      if (departureCity.isNotEmpty ||
                          departureDate.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionTitle('Keberangkatan'),
                        const SizedBox(height: 12),
                        if (departureCity.isNotEmpty)
                          _detailRow(
                            Icons.location_on_outlined,
                            'Kota keberangkatan',
                            departureCity,
                          ),
                        if (departureDate.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _detailRow(
                            Icons.event_outlined,
                            'Tanggal keberangkatan',
                            departureDate,
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // Harga paket
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: safarLightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mulai dari'),
                            const SizedBox(height: 6),
                            Text(
                              formatRupiah(startingPrice),
                              style: const TextStyle(
                                color: safarGreen,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Per jamaah',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      // Harga kamar
                      if (roomPrices.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Pilihan Harga Kamar'),
                        const SizedBox(height: 12),
                        ...roomPrices.map(
                          (room) =>
                              _priceRow(room.key, formatRupiah(room.value)),
                        ),
                      ],

                      // Hotel
                      if (hotelMakkah.isNotEmpty ||
                          hotelMadinah.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Akomodasi Hotel'),
                        const SizedBox(height: 12),

                        if (hotelMakkah.isNotEmpty)
                          _hotelCard(
                            'Hotel Makkah',
                            hotelMakkah,
                            makkahRating,
                            Icons.mosque_outlined,
                          ),

                        if (hotelMakkah.isNotEmpty && hotelMadinah.isNotEmpty)
                          const SizedBox(height: 12),

                        if (hotelMadinah.isNotEmpty)
                          _hotelCard(
                            'Hotel Madinah',
                            hotelMadinah,
                            madinahRating,
                            Icons.hotel_outlined,
                          ),
                      ],

                      // Deskripsi
                      const SizedBox(height: 28),
                      _sectionTitle('Deskripsi Paket'),
                      const SizedBox(height: 10),
                      Text(
                        description.isNotEmpty
                            ? description
                            : 'Deskripsi paket belum tersedia.',
                        style: const TextStyle(fontSize: 14, height: 1.7),
                      ),

                      // Fasilitas lama
                      if (facilities.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Fasilitas Paket'),
                        const SizedBox(height: 12),
                        ...facilities.map(
                          (item) => _bulletItem(
                            item,
                            Icons.check_circle_outline,
                            safarGreen,
                          ),
                        ),
                      ],

                      // Harga termasuk
                      if (included.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Harga Termasuk'),
                        const SizedBox(height: 12),
                        ...included.map(
                          (item) =>
                              _bulletItem(item, Icons.check_circle, safarGreen),
                        ),
                      ],

                      // Harga tidak termasuk
                      if (excluded.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Harga Tidak Termasuk'),
                        const SizedBox(height: 12),
                        ...excluded.map(
                          (item) => _bulletItem(
                            item,
                            Icons.cancel_outlined,
                            Colors.redAccent,
                          ),
                        ),
                      ],

                      // Keunggulan
                      if (advantages.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionTitle('Keunggulan Paket'),
                        const SizedBox(height: 12),
                        ...advantages.map(
                          (item) => _bulletItem(
                            item,
                            Icons.star_outline_rounded,
                            safarGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tombol navigasi tetap di bagian bawah.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItineraryPage(package: package),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Itinerary'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: safarGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingPage(package: package),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Pesan Paket'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: safarGreen, size: 26),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: safarGreen, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            price,
            style: const TextStyle(
              color: safarGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hotelCard(String title, String name, dynamic rating, IconData icon) {
    final stars = int.tryParse(rating?.toString() ?? '') ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: safarLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: safarGreen, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: List.generate(
                      stars,
                      (_) =>
                          const Icon(Icons.star, size: 17, color: Colors.amber),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 230,
      color: safarLightGreen,
      child: const Icon(Icons.mosque_outlined, size: 85, color: safarGreen),
    );
  }
}
