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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
    final number = num.tryParse(price.toString()) ?? 0;
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
    if (type == 'umrah_plus_turki') {
      return 'Umrah Plus Turki';
    }
    return 'Umrah Reguler';
  }

  Future<void> _showPackageForm({Map<String, dynamic>? package}) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: package?['name']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: package?['price']?.toString() ?? '',
    );
    final durationController = TextEditingController(
      text: package?['duration_days']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: package?['description']?.toString() ?? '',
    );
    final facilitiesController = TextEditingController(
      text: package?['facilities']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: package?['image_url']?.toString() ?? '',
    );

    String selectedType =
        package?['package_type']?.toString() ?? 'umrah_reguler';
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(package == null ? 'Tambah Paket' : 'Edit Paket'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama paket',
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'Jenis paket',
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
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga (Rp)',
                          ),
                          validator: (value) {
                            final price = num.tryParse(value?.trim() ?? '');
                            if (price == null || price < 0) {
                              return 'Masukkan harga yang valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durasi (hari)',
                          ),
                          validator: (value) {
                            final days = int.tryParse(value?.trim() ?? '');
                            if (days == null || days <= 0) {
                              return 'Durasi harus lebih dari 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Deskripsi',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: facilitiesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Fasilitas',
                            hintText: 'Contoh: hotel, makan, transportasi',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imageController,
                          decoration: const InputDecoration(
                            labelText: 'URL gambar (opsional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            final data = {
                              'name': nameController.text.trim(),
                              'packageType': selectedType,
                              'price': double.parse(
                                priceController.text.trim(),
                              ),
                              'durationDays': int.parse(
                                durationController.text.trim(),
                              ),
                              'description': descriptionController.text.trim(),
                              'facilities': facilitiesController.text.trim(),
                              'imageUrl': imageController.text.trim(),
                            };

                            if (package == null) {
                              await _service.addPackage(
                                name: data['name'] as String,
                                packageType: data['packageType'] as String,
                                price: data['price'] as double,
                                durationDays: data['durationDays'] as int,
                                description:
                                    (data['description'] as String).isEmpty
                                    ? null
                                    : data['description'] as String,
                                facilities:
                                    (data['facilities'] as String).isEmpty
                                    ? null
                                    : data['facilities'] as String,
                                imageUrl: (data['imageUrl'] as String).isEmpty
                                    ? null
                                    : data['imageUrl'] as String,
                              );
                            } else {
                              await _service.updatePackage(
                                id: package['id'].toString(),
                                name: data['name'] as String,
                                packageType: data['packageType'] as String,
                                price: data['price'] as double,
                                durationDays: data['durationDays'] as int,
                                description:
                                    (data['description'] as String).isEmpty
                                    ? null
                                    : data['description'] as String,
                                facilities:
                                    (data['facilities'] as String).isEmpty
                                    ? null
                                    : data['facilities'] as String,
                                imageUrl: (data['imageUrl'] as String).isEmpty
                                    ? null
                                    : data['imageUrl'] as String,
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    durationController.dispose();
    descriptionController.dispose();
    facilitiesController.dispose();
    imageController.dispose();
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Paket Umrah'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      floatingActionButton: !_loading && _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showPackageForm(),
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
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat data.\n$_error',
                      textAlign: TextAlign.center,
                    ),
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
                child: Text(
                  'Halaman ini hanya dapat diakses oleh admin.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _packages.isEmpty
          ? const Center(
              child: Text(
                'Belum ada paket.\nTekan Tambah Paket untuk memulai.',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  final package = _packages[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package['name']?.toString() ?? 'Tanpa nama',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatType(package['package_type']?.toString()),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatPrice(package['price']),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Durasi: ${package['duration_days']} hari'),
                          const SizedBox(height: 8),
                          Text(
                            package['description']?.toString() ??
                                'Belum ada deskripsi.',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _showPackageForm(package: package),
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit'),
                              ),
                              TextButton.icon(
                                onPressed: () => _deletePackage(package),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
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
                },
              ),
            ),
    );
  }
}
