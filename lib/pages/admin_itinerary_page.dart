import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/package_service.dart';
import '../services/itinerary_service.dart';

const Color itineraryGreen = Color(0xFF176B50);
const Color itineraryLightGreen = Color(0xFFE1F2E8);

class AdminItineraryPage extends StatefulWidget {
  const AdminItineraryPage({super.key});

  @override
  State<AdminItineraryPage> createState() => _AdminItineraryPageState();
}

class _AdminItineraryPageState extends State<AdminItineraryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PackageService _packageService = PackageService();
  final ItineraryService _itineraryService = ItineraryService();

  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _itinerary = [];

  String? _selectedPackageId;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Pastikan hanya admin yang dapat membuka halaman ini.
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        throw Exception('Halaman ini hanya dapat diakses oleh admin.');
      }

      final packages = await _packageService.getPackages();

      if (!mounted) return;

      setState(() {
        _packages = packages;
        _selectedPackageId = packages.isNotEmpty
            ? packages.first['id'].toString()
            : null;
      });

      if (_selectedPackageId != null) {
        await _loadItinerary();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadItinerary() async {
    final packageId = _selectedPackageId;
    if (packageId == null) return;

    setState(() => _loading = true);

    try {
      final data = await _itineraryService.getItinerary(packageId);

      if (!mounted) return;

      setState(() {
        _itinerary = data;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _packageName(Map<String, dynamic> package) {
    return package['name']?.toString() ?? 'Paket Perjalanan';
  }

  int _packageDuration(Map<String, dynamic> package) {
    return int.tryParse(package['duration_days']?.toString() ?? '') ?? 0;
  }

  Future<void> _showItineraryForm({Map<String, dynamic>? item}) async {
    if (_selectedPackageId == null) return;

    final formKey = GlobalKey<FormState>();
    final dayController = TextEditingController(
      text: item?['day_number']?.toString() ?? '',
    );
    final titleController = TextEditingController(
      text: item?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?['description']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: item?['location']?.toString() ?? '',
    );

    final existingTime = item?['start_time']?.toString();
    final timeController = TextEditingController(
      text: existingTime == null || existingTime.isEmpty
          ? ''
          : existingTime.substring(0, 5),
    );

    final package = _packages.firstWhere(
      (p) => p['id'].toString() == _selectedPackageId,
      orElse: () => <String, dynamic>{},
    );

    final duration = _packageDuration(package);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hari ke- (1–$duration)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final day = int.tryParse(value ?? '');

                      if (day == null || day < 1) {
                        return 'Masukkan nomor hari yang valid.';
                      }

                      if (duration > 0 && day > duration) {
                        return 'Durasi paket hanya $duration hari.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul kegiatan',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Judul kegiatan wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi kegiatan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: timeController,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Waktu (HH:MM)',
                      hintText: '08:00',
                      helperText: 'Kosongkan jika waktu belum ditentukan.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final time = value?.trim() ?? '';

                      if (time.isEmpty) return null;

                      if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                          .hasMatch(time)) {
                        return 'Gunakan format 08:00.';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: itineraryGreen),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      dayController.dispose();
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      timeController.dispose();
      return;
    }

    final dayNumber = int.parse(dayController.text.trim());
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final location = locationController.text.trim();
    final time = timeController.text.trim();

    await Future<void>.delayed(const Duration(milliseconds: 300));

    dayController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    timeController.dispose();

    // Cegah dua kegiatan memakai nomor hari yang sama.
    final duplicateDay = _itinerary.any((existing) {
      final sameDay = existing['day_number'].toString() == dayNumber.toString();
      final differentItem =
          existing['id'].toString() != (item?['id']?.toString() ?? '');
      return sameDay && differentItem;
    });

    if (duplicateDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hari ke-$dayNumber sudah memiliki jadwal.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (item == null) {
        await _itineraryService.addItinerary(
          packageId: _selectedPackageId!,
          dayNumber: dayNumber,
          title: title,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          startTime: time.isEmpty ? null : '$time:00',
        );
      } else {
        await _itineraryService.updateItinerary(
          id: item['id'].toString(),
          dayNumber: dayNumber,
          title: title,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          startTime: time.isEmpty ? null : '$time:00',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null
                ? 'Jadwal berhasil ditambahkan.'
                : 'Jadwal berhasil diperbarui.',
          ),
        ),
      );

      await _loadItinerary();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan jadwal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItinerary(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text(
          'Jadwal Hari ${item['day_number']} — ${item['title']} '
          'akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      await _itineraryService.deleteItinerary(item['id'].toString());

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jadwal berhasil dihapus.')));

      await _loadItinerary();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menghapus jadwal: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _packages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Itinerary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _packages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Itinerary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _initializePage,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Itinerary'),
        backgroundColor: itineraryGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _packages.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : () => _showItineraryForm(),
              backgroundColor: itineraryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal'),
            ),
      body: _packages.isEmpty
          ? const Center(child: Text('Belum ada paket perjalanan.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPackageId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Paket Perjalanan',
                      border: OutlineInputBorder(),
                    ),
                    items: _packages.map((package) {
                      return DropdownMenuItem<String>(
                        value: package['id'].toString(),
                        child: Text(
                          '${_packageName(package)} '
                          '(${_packageDuration(package)} hari)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) async {
                            if (value == null) return;

                            setState(() {
                              _selectedPackageId = value;
                              _itinerary = [];
                            });

                            await _loadItinerary();
                          },
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _itinerary.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Belum ada jadwal untuk paket ini.\n'
                              'Tekan Tambah Jadwal untuk memulai.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _itinerary.length,
                          itemBuilder: (context, index) {
                            final item = _itinerary[index];

                            final time = item['start_time']?.toString() ?? '';
                            final displayTime = time.isEmpty
                                ? 'Waktu belum ditentukan'
                                : time.substring(0, 5);

                            final location = item['location']?.toString() ?? '';
                            final description =
                                item['description']?.toString() ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: itineraryLightGreen,
                                          child: Text(
                                            '${item['day_number']}',
                                            style: const TextStyle(
                                              color: itineraryGreen,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item['title']?.toString() ??
                                                'Kegiatan',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Edit jadwal',
                                          onPressed: _saving
                                              ? null
                                              : () => _showItineraryForm(
                                                  item: item,
                                                ),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'Hapus jadwal',
                                          onPressed: _saving
                                              ? null
                                              : () => _deleteItinerary(item),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Waktu: $displayTime'),
                                    if (location.isNotEmpty)
                                      Text('Lokasi: $location'),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(description),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
