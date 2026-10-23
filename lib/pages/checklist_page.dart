import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final Map<String, List<String>> _defaultChecklist = {
    'Dokumen Perjalanan': [
      'Paspor',
      'Visa Umrah',
      'Tiket pesawat',
      'Kartu identitas',
      'Dokumen perjalanan dari biro',
    ],
    'Perlengkapan Ibadah': [
      'Pakaian ihram',
      'Mukena atau perlengkapan salat',
      'Sajadah kecil',
      'Al-Qur’an atau aplikasi Al-Qur’an',
      'Buku panduan doa dan ibadah',
    ],
    'Perlengkapan Pribadi': [
      'Pakaian sehari-hari',
      'Sandal atau sepatu yang nyaman',
      'Perlengkapan mandi',
      'Obat pribadi yang diperlukan',
      'Tas kecil untuk keperluan harian',
    ],
    'Persiapan Sebelum Berangkat': [
      'Mempelajari tata cara Umrah',
      'Memahami larangan ihram',
      'Mengikuti arahan manasik',
      'Memastikan jadwal keberangkatan',
      'Memastikan barang bawaan sudah lengkap',
    ],
  };

  late Map<String, List<String>> _checklist;

  final Set<String> _completedItems = {};
  final TextEditingController _itemController = TextEditingController();

  static const String _completedStorageKey =
      'safarmate_checklist_completed_items';

  static const String _customStorageKey = 'safarmate_checklist_custom_items';

  bool _isLoading = true;
  bool _isSaving = false;

  int get _totalItems =>
      _checklist.values.fold(0, (total, items) => total + items.length);

  double get _progress =>
      _totalItems == 0 ? 0 : _completedItems.length / _totalItems;

  @override
  void initState() {
    super.initState();

    _checklist = {
      for (final entry in _defaultChecklist.entries)
        entry.key: List<String>.from(entry.value),
    };

    _loadChecklist();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _loadChecklist() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedCustomItems = prefs.getStringList(_customStorageKey) ?? [];

      final savedCompletedItems =
          prefs.getStringList(_completedStorageKey) ?? [];

      if (!mounted) return;

      setState(() {
        for (final savedItem in savedCustomItems) {
          final separator = savedItem.indexOf('|');

          if (separator <= 0) continue;

          final category = savedItem.substring(0, separator);
          final item = savedItem.substring(separator + 1);

          if (_checklist.containsKey(category) &&
              item.trim().isNotEmpty &&
              !_checklist[category]!.contains(item)) {
            _checklist[category]!.add(item);
          }
        }

        _completedItems
          ..clear()
          ..addAll(
            savedCompletedItems.where(
              (item) => _checklist.values.any((items) => items.contains(item)),
            ),
          );

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist gagal dimuat. Silakan coba lagi.'),
        ),
      );
    }
  }

  Future<void> _saveChecklist() async {
    if (_isSaving) return;

    _isSaving = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final customItems = <String>[];

      for (final entry in _checklist.entries) {
        final defaults = _defaultChecklist[entry.key] ?? [];

        for (final item in entry.value) {
          if (!defaults.contains(item)) {
            customItems.add('${entry.key}|$item');
          }
        }
      }

      await prefs.setStringList(_customStorageKey, customItems);
      await prefs.setStringList(_completedStorageKey, _completedItems.toList());
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist belum berhasil disimpan.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _toggleItem(String item, bool checked) async {
    setState(() {
      if (checked) {
        _completedItems.add(item);
      } else {
        _completedItems.remove(item);
      }
    });

    await _saveChecklist();
  }

  Future<void> _showAddItemDialog() async {
    _itemController.clear();

    String selectedCategory = _checklist.keys.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Item Checklist'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _itemController,
                    autofocus: true,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Nama item',
                      hintText: 'Contoh: Kacamata',
                      prefixIcon: const Icon(Icons.check_box_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _checklist.keys.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: safarGreen),
                  onPressed: () {
                    final item = _itemController.text.trim();

                    if (item.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama item tidak boleh kosong.'),
                        ),
                      );
                      return;
                    }

                    if (_checklist[selectedCategory]!.any(
                      (existing) =>
                          existing.toLowerCase() == item.toLowerCase(),
                    )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Item tersebut sudah ada di kategori ini.',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _checklist[selectedCategory]!.add(item);
                    });

                    Navigator.pop(dialogContext, true);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _saveChecklist();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item berhasil ditambahkan.')),
      );
    }
  }

  Future<void> _deleteItem(String category, String item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('Item "$item" akan dihapus dari checklist kamu.'),
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

    setState(() {
      _checklist[category]!.remove(item);
      _completedItems.remove(item);
    });

    await _saveChecklist();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Item berhasil dihapus.')));
  }

  Future<void> _resetChecklist() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset checklist?'),
        content: const Text(
          'Semua tanda selesai akan dihapus. Item tambahan '
          'milikmu tetap dipertahankan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: safarGreen),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true || !mounted) return;

    setState(() {
      _completedItems.clear();
    });

    await _saveChecklist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Persiapan Umrah'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Reset checklist',
            onPressed: _isLoading ? null : _resetChecklist,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddItemDialog,
              backgroundColor: safarGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Item'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: safarGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Persiapkan perjalananmu!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_completedItems.length} dari $_totalItems persiapan selesai',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 10,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFB8F0D0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).round()}% selesai',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  elevation: 0,
                  color: Color(0xFFFFF4D8),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.brown),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Checklist ini merupakan panduan umum. '
                            'Pastikan persyaratan dokumen dan barang '
                            'bawaan sesuai arahan biro perjalanan serta '
                            'kondisi keberangkatanmu.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in _checklist.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: safarGreen,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: entry.value.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Belum ada item di kategori ini.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < entry.value.length; i++) ...[
                                CheckboxListTile(
                                  value: _completedItems.contains(
                                    entry.value[i],
                                  ),
                                  onChanged: (value) => _toggleItem(
                                    entry.value[i],
                                    value ?? false,
                                  ),
                                  activeColor: safarGreen,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    entry.value[i],
                                    style: TextStyle(
                                      decoration:
                                          _completedItems.contains(
                                            entry.value[i],
                                          )
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color:
                                          _completedItems.contains(
                                            entry.value[i],
                                          )
                                          ? Colors.black54
                                          : Colors.black87,
                                    ),
                                  ),
                                  secondary: IconButton(
                                    tooltip: 'Hapus item',
                                    onPressed: () =>
                                        _deleteItem(entry.key, entry.value[i]),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                                if (i < entry.value.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_totalItems > 0 && _completedItems.length == _totalItems)
                  const Card(
                    color: safarLightGreen,
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: safarGreen, size: 30),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Semua checklist sudah ditandai selesai. '
                              'Semoga persiapan Umrahmu lancar!',
                              style: TextStyle(
                                color: safarGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
