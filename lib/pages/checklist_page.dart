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
  final Map<String, List<String>> _checklist = {
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

  final Set<String> _completedItems = {};
  static const String _storageKey = 'safarmate_checklist_completed_items';
  bool _isLoading = true;

  int get _totalItems =>
      _checklist.values.fold(0, (total, items) => total + items.length);

  double get _progress =>
      _totalItems == 0 ? 0 : _completedItems.length / _totalItems;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedItems = prefs.getStringList(_storageKey) ?? <String>[];

      if (!mounted) return;
      setState(() {
        _completedItems
          ..clear()
          ..addAll(
            savedItems.where(
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _completedItems.toList());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist belum berhasil disimpan.')),
      );
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

  Future<void> _resetChecklist() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset checklist?'),
        content: const Text(
          'Semua tanda selesai akan dihapus dan checklist '
          'dikembalikan ke kondisi awal.',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
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
                            'Pastikan persyaratan dokumen dan barang bawaan '
                            'sesuai arahan biro perjalanan serta kondisi '
                            'keberangkatanmu.',
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
                    child: Column(
                      children: [
                        for (int i = 0; i < entry.value.length; i++) ...[
                          CheckboxListTile(
                            value: _completedItems.contains(entry.value[i]),
                            onChanged: (value) =>
                                _toggleItem(entry.value[i], value ?? false),
                            activeColor: safarGreen,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              entry.value[i],
                              style: TextStyle(
                                decoration:
                                    _completedItems.contains(entry.value[i])
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: _completedItems.contains(entry.value[i])
                                    ? Colors.black54
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (i < entry.value.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_completedItems.length == _totalItems)
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
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
