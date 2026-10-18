import 'package:flutter/material.dart';

import 'booking_page.dart';
import 'itinerary_page.dart';

class PackageDetailPage extends StatelessWidget {
  final Map<String, dynamic> package;

  const PackageDetailPage({super.key, required this.package});

  String formatRupiah(dynamic value) {
    final price = num.tryParse(value.toString()) ?? 0;
    final formatted = price.toStringAsFixed(0);

    final result = formatted.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $result';
  }

  @override
  Widget build(BuildContext context) {
    final name = package['name']?.toString() ?? 'Paket Umrah';
    final type = package['package_type']?.toString() ?? '';
    final price = package['price'] ?? 0;
    final duration = package['duration_days']?.toString() ?? '-';
    final description = package['description']?.toString() ?? '';
    final facilities = package['facilities']?.toString() ?? '';
    final imageUrl = package['image_url']?.toString() ?? '';

    final packageType = type == 'umrah_plus_turki'
        ? 'Umrah Plus Turki'
        : 'Umrah Reguler';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Paket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _imagePlaceholder();
                  },
                ),
              )
            else
              _imagePlaceholder(),

            const SizedBox(height: 20),

            Text(
              packageType,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Harga Paket', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      formatRupiah(price),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined),
                        const SizedBox(width: 10),
                        Text('Durasi perjalanan: $duration hari'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Deskripsi Paket',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty
                  ? description
                  : 'Belum ada deskripsi paket.',
            ),

            const SizedBox(height: 20),

            const Text(
              'Fasilitas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (facilities.isNotEmpty)
              ...facilities
                  .split(',')
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.trim())),
                        ],
                      ),
                    ),
                  )
            else
              const Text('Informasi fasilitas belum tersedia.'),

            const SizedBox(height: 28),

            // Tombol untuk melihat jadwal perjalanan paket
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItineraryPage(package: package),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Lihat Itinerary'),
              ),
            ),

            const SizedBox(height: 12),

            // Tombol pemesanan tetap tersedia
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingPage(package: package),
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
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.mosque_outlined, size: 80, color: Colors.grey),
    );
  }
}
