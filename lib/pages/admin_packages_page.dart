import 'package:flutter/material.dart';

import '../services/package_service.dart';

class AdminPackagesPage extends StatefulWidget {
  const AdminPackagesPage({super.key});

  @override
  State<AdminPackagesPage> createState() => _AdminPackagesPageState();
}

class _AdminPackagesPageState extends State<AdminPackagesPage> {
  final PackageService _service = PackageService();

  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;

  static const Color safarGreen = Color(0xFF176B50);
  static const Color safarLightGreen = Color(0xFFE1F2E8);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final admin = await _service.isAdmin();

      if (!admin) {
        if (!mounted) return;

        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }

      final packages = await _service.getPackages();

      if (!mounted) return;

      setState(() {
        _isAdmin = true;
        _packages = packages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatPrice(dynamic price) {
    final number = num.tryParse(price?.toString() ?? '') ?? 0;
    final text = number.toInt().toString();
    final result = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(text[i]);
    }

    return 'Rp$result';
  }

  String _formatType(String? type) {
    switch (type) {
      case 'umrah_reguler':
        return 'Umrah Reguler';
      case 'umrah_plus_turki':
        return 'Umrah Plus Turki';
      default:
        return type ?? 'Paket Umrah';
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';

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

  String? _optionalText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  double? _optionalPrice(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  int? _optionalRating(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  TextEditingController _createController(
    Map<String, dynamic>? package,
    String key,
  ) {
    return TextEditingController(text: package?[key]?.toString() ?? '');
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(label, hint: hint, icon: icon),
    );
  }

  String? _validateOptionalPrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final number = double.tryParse(value.trim());

    if (number == null || number < 0) {
      return 'Masukkan harga yang valid';
    }

    return null;
  }

  String? _validateOptionalRating(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final rating = int.tryParse(value.trim());

    if (rating == null || rating < 1 || rating > 5) {
      return 'Rating harus berupa angka 1 sampai 5';
    }

    return null;
  }

  Future<void> _showPackageForm({Map<String, dynamic>? package}) async {
    final formKey = GlobalKey<FormState>();

    final controllers = <String, TextEditingController>{
      'name': _createController(package, 'name'),
      'price': _createController(package, 'price'),
      'duration_days': _createController(package, 'duration_days'),
      'description': _createController(package, 'description'),
      'facilities': _createController(package, 'facilities'),
      'image_url': _createController(package, 'image_url'),
      'airline': _createController(package, 'airline'),
      'departure_date': _createController(package, 'departure_date'),
      'departure_city': _createController(package, 'departure_city'),
      'hotel_makkah': _createController(package, 'hotel_makkah'),
      'hotel_makkah_rating': _createController(package, 'hotel_makkah_rating'),
      'hotel_madinah': _createController(package, 'hotel_madinah'),
      'hotel_madinah_rating': _createController(
        package,
        'hotel_madinah_rating',
      ),
      'price_quad': _createController(package, 'price_quad'),
      'price_triple': _createController(package, 'price_triple'),
      'price_double': _createController(package, 'price_double'),
      'included_facilities': _createController(package, 'included_facilities'),
      'excluded_facilities': _createController(package, 'excluded_facilities'),
      'advantages': _createController(package, 'advantages'),
    };

    String selectedType =
        package?['package_type']?.toString() ?? 'umrah_reguler';

    bool saving = false;

    Future<void> chooseDepartureDate(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final currentText = controllers['departure_date']!.text.trim();
      final parsedDate = DateTime.tryParse(currentText);
      final now = DateTime.now();

      final selectedDate = await showDatePicker(
        context: dialogContext,
        initialDate: parsedDate ?? now,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        helpText: 'Pilih tanggal keberangkatan',
      );

      if (selectedDate == null) return;

      setDialogState(() {
        controllers['departure_date']!.text =
            '${selectedDate.year.toString().padLeft(4, '0')}-'
            '${selectedDate.month.toString().padLeft(2, '0')}-'
            '${selectedDate.day.toString().padLeft(2, '0')}';
      });
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  package == null ? 'Tambah Paket Umrah' : 'Edit Paket Umrah',
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Informasi Paket',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: safarGreen,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _textField(
                            controllers['name']!,
                            'Nama paket *',
                            hint: 'Contoh: Umrah Reguler 12 Hari',
                            icon: Icons.card_travel,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama paket wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: _inputDecoration(
                              'Jenis paket *',
                              icon: Icons.category_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'umrah_reguler',
                                child: Text('Umrah Reguler'),
                              ),
                              DropdownMenuItem(
                                value: 'umrah_plus_turki',
                                child: Text('Umrah Plus Turki'),
                              ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        selectedType = value;
                                      });
                                    }
                                  },
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['price']!,
                            'Harga utama (Rp) *',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            icon: Icons.payments_outlined,
                            validator: (value) {
                              final price = double.tryParse(
                                value?.trim() ?? '',
                              );

                              if (price == null || price < 0) {
                                return 'Masukkan harga yang valid';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['duration_days']!,
                            'Durasi (hari) *',
                            keyboardType: TextInputType.number,
                            icon: Icons.calendar_month_outlined,
                            validator: (value) {
                              final days = int.tryParse(value?.trim() ?? '');

                              if (days == null || days <= 0) {
                                return 'Durasi harus lebih dari 0';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['description']!,
                            'Deskripsi paket',
                            maxLines: 3,
                            icon: Icons.description_outlined,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['image_url']!,
                            'URL gambar',
                            hint: 'https://...',
                            icon: Icons.image_outlined,
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),

                          const Text(
                            'Keberangkatan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: safarGreen,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _textField(
                            controllers['airline']!,
                            'Maskapai',
                            hint: 'Contoh: Garuda Indonesia',
                            icon: Icons.flight_outlined,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: controllers['departure_date'],
                            readOnly: true,
                            onTap: saving
                                ? null
                                : () => chooseDepartureDate(
                                    dialogContext,
                                    setDialogState,
                                  ),
                            decoration:
                                _inputDecoration(
                                  'Tanggal keberangkatan',
                                  hint: 'Pilih tanggal',
                                  icon: Icons.event_outlined,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: saving
                                        ? null
                                        : () => chooseDepartureDate(
                                            dialogContext,
                                            setDialogState,
                                          ),
                                    icon: const Icon(Icons.calendar_month),
                                  ),
                                ),
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['departure_city']!,
                            'Kota keberangkatan',
                            hint: 'Contoh: Jakarta',
                            icon: Icons.location_on_outlined,
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),

                          const Text(
                            'Harga Kamar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: safarGreen,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _textField(
                            controllers['price_quad']!,
                            'Harga Quad (4 orang/kamar)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            icon: Icons.people_outline,
                            validator: _validateOptionalPrice,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['price_triple']!,
                            'Harga Triple (3 orang/kamar)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            icon: Icons.people_outline,
                            validator: _validateOptionalPrice,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['price_double']!,
                            'Harga Double (2 orang/kamar)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            icon: Icons.people_outline,
                            validator: _validateOptionalPrice,
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),

                          const Text(
                            'Akomodasi Hotel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: safarGreen,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _textField(
                            controllers['hotel_makkah']!,
                            'Nama hotel Makkah',
                            icon: Icons.mosque_outlined,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['hotel_makkah_rating']!,
                            'Rating hotel Makkah (1–5)',
                            keyboardType: TextInputType.number,
                            icon: Icons.star_outline,
                            validator: _validateOptionalRating,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['hotel_madinah']!,
                            'Nama hotel Madinah',
                            icon: Icons.hotel_outlined,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['hotel_madinah_rating']!,
                            'Rating hotel Madinah (1–5)',
                            keyboardType: TextInputType.number,
                            icon: Icons.star_outline,
                            validator: _validateOptionalRating,
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),

                          const Text(
                            'Fasilitas dan Keunggulan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: safarGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Untuk daftar fasilitas atau keunggulan, '
                            'masukkan satu item per baris.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _textField(
                            controllers['facilities']!,
                            'Fasilitas paket',
                            hint: 'Hotel\nMakan\nTransportasi',
                            maxLines: 3,
                            icon: Icons.checklist,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['included_facilities']!,
                            'Harga termasuk',
                            hint: 'Tiket pesawat\nHotel\nVisa',
                            maxLines: 3,
                            icon: Icons.check_circle_outline,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['excluded_facilities']!,
                            'Harga tidak termasuk',
                            hint: 'Pengeluaran pribadi\nBiaya tambahan',
                            maxLines: 3,
                            icon: Icons.remove_circle_outline,
                          ),
                          const SizedBox(height: 12),

                          _textField(
                            controllers['advantages']!,
                            'Keunggulan paket',
                            hint:
                                'Hotel dekat masjid\nPembimbing berpengalaman',
                            maxLines: 3,
                            icon: Icons.star_outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: safarGreen),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            final departureDate = _optionalText(
                              controllers['departure_date']!.text,
                            );

                            // Pastikan tanggal yang disimpan valid.
                            if (departureDate != null &&
                                DateTime.tryParse(departureDate) == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tanggal keberangkatan tidak valid',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => saving = true);

                            try {
                              final name = controllers['name']!.text.trim();
                              final price = double.parse(
                                controllers['price']!.text.trim(),
                              );
                              final durationDays = int.parse(
                                controllers['duration_days']!.text.trim(),
                              );

                              final description = _optionalText(
                                controllers['description']!.text,
                              );
                              final facilities = _optionalText(
                                controllers['facilities']!.text,
                              );
                              final imageUrl = _optionalText(
                                controllers['image_url']!.text,
                              );
                              final airline = _optionalText(
                                controllers['airline']!.text,
                              );
                              final departureCity = _optionalText(
                                controllers['departure_city']!.text,
                              );
                              final hotelMakkah = _optionalText(
                                controllers['hotel_makkah']!.text,
                              );
                              final hotelMadinah = _optionalText(
                                controllers['hotel_madinah']!.text,
                              );

                              final hotelMakkahRating = _optionalRating(
                                controllers['hotel_makkah_rating']!.text,
                              );
                              final hotelMadinahRating = _optionalRating(
                                controllers['hotel_madinah_rating']!.text,
                              );

                              final priceQuad = _optionalPrice(
                                controllers['price_quad']!.text,
                              );
                              final priceTriple = _optionalPrice(
                                controllers['price_triple']!.text,
                              );
                              final priceDouble = _optionalPrice(
                                controllers['price_double']!.text,
                              );

                              final includedFacilities = _optionalText(
                                controllers['included_facilities']!.text,
                              );
                              final excludedFacilities = _optionalText(
                                controllers['excluded_facilities']!.text,
                              );
                              final advantages = _optionalText(
                                controllers['advantages']!.text,
                              );

                              if (package == null) {
                                await _service.addPackage(
                                  name: name,
                                  packageType: selectedType,
                                  price: price,
                                  durationDays: durationDays,
                                  description: description,
                                  facilities: facilities,
                                  imageUrl: imageUrl,
                                  airline: airline,
                                  departureDate: departureDate,
                                  departureCity: departureCity,
                                  hotelMakkah: hotelMakkah,
                                  hotelMakkahRating: hotelMakkahRating,
                                  hotelMadinah: hotelMadinah,
                                  hotelMadinahRating: hotelMadinahRating,
                                  priceQuad: priceQuad,
                                  priceTriple: priceTriple,
                                  priceDouble: priceDouble,
                                  includedFacilities: includedFacilities,
                                  excludedFacilities: excludedFacilities,
                                  advantages: advantages,
                                );
                              } else {
                                await _service.updatePackage(
                                  id: package['id'].toString(),
                                  name: name,
                                  packageType: selectedType,
                                  price: price,
                                  durationDays: durationDays,
                                  description: description,
                                  facilities: facilities,
                                  imageUrl: imageUrl,
                                  airline: airline,
                                  departureDate: departureDate,
                                  departureCity: departureCity,
                                  hotelMakkah: hotelMakkah,
                                  hotelMakkahRating: hotelMakkahRating,
                                  hotelMadinah: hotelMadinah,
                                  hotelMadinahRating: hotelMadinahRating,
                                  priceQuad: priceQuad,
                                  priceTriple: priceTriple,
                                  priceDouble: priceDouble,
                                  includedFacilities: includedFacilities,
                                  excludedFacilities: excludedFacilities,
                                  advantages: advantages,
                                );
                              }

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext);

                              await _loadData();

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    package == null
                                        ? 'Paket berhasil ditambahkan'
                                        : 'Paket berhasil diperbarui',
                                  ),
                                ),
                              );
                            } catch (e) {
                              setDialogState(() => saving = false);

                              if (!dialogContext.mounted) return;

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menyimpan paket: $e'),
                                ),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan Paket'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _deletePackage(Map<String, dynamic> package) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Paket'),
        content: Text('Yakin ingin menghapus paket "${package['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deletePackage(package['id'].toString());
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paket berhasil dihapus')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menghapus paket: $e')));
    }
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final name = package['name']?.toString() ?? 'Tanpa nama';
    final imageUrl = package['image_url']?.toString() ?? '';
    final description = package['description']?.toString() ?? '';
    final departureCity = package['departure_city']?.toString() ?? '';
    final departureDate = package['departure_date'];
    final airline = package['airline']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: safarLightGreen,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.mosque_outlined,
                              size: 40,
                              color: safarGreen,
                            ),
                          )
                        : const Icon(
                            Icons.mosque_outlined,
                            size: 40,
                            color: safarGreen,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: safarLightGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatType(package['package_type']?.toString()),
                          style: const TextStyle(
                            color: safarGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatPrice(package['price']),
                        style: const TextStyle(
                          fontSize: 16,
                          color: safarGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Durasi: ${package['duration_days'] ?? '-'} hari',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
            ],

            const Divider(height: 24),

            if (airline.isNotEmpty)
              _infoRow(Icons.flight_outlined, 'Maskapai', airline),

            if (departureCity.isNotEmpty)
              _infoRow(
                Icons.location_on_outlined,
                'Keberangkatan',
                departureCity,
              ),

            if (departureDate != null && departureDate.toString().isNotEmpty)
              _infoRow(
                Icons.calendar_month_outlined,
                'Tanggal',
                _formatDate(departureDate),
              ),

            if (package['price_quad'] != null ||
                package['price_triple'] != null ||
                package['price_double'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Harga kamar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              if (package['price_quad'] != null)
                _infoRow(
                  Icons.people_outline,
                  'Quad',
                  _formatPrice(package['price_quad']),
                ),
              if (package['price_triple'] != null)
                _infoRow(
                  Icons.people_outline,
                  'Triple',
                  _formatPrice(package['price_triple']),
                ),
              if (package['price_double'] != null)
                _infoRow(
                  Icons.people_outline,
                  'Double',
                  _formatPrice(package['price_double']),
                ),
            ],

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showPackageForm(package: package),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _deletePackage(package),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: safarGreen),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Paket Umrah'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: !_loading && _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showPackageForm(),
              backgroundColor: safarGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Paket'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal memuat data paket.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : !_isAdmin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 54,
                      color: safarGreen,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Halaman ini hanya dapat diakses oleh admin.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : _packages.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: safarGreen,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada paket umrah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tekan Tambah Paket untuk memulai.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  return _buildPackageCard(_packages[index]);
                },
              ),
            ),
    );
  }
}
