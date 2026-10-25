import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _tripNameController = TextEditingController(
    text: 'Tes Umrah SafarMate',
  );
  final _originCityController = TextEditingController(text: 'Jakarta');

  DateTime? _departureDate;
  DateTime? _returnDate;

  bool _isLoading = false;
  String _message = '';
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    _originCityController.dispose();
    super.dispose();
  }

  String _dateToString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDate({required bool departure}) async {
    final now = DateTime.now();

    final initialDate = departure
        ? (_departureDate ?? now)
        : (_returnDate ?? _departureDate ?? now);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (departure) {
        _departureDate = selected;

        if (_returnDate != null && _returnDate!.isBefore(selected)) {
          _returnDate = null;
        }
      } else {
        _returnDate = selected;
      }
    });
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_departureDate == null) {
      setState(() {
        _message = 'Pilih tanggal keberangkatan terlebih dahulu.';
      });
      return;
    }

    if (_returnDate != null && _returnDate!.isBefore(_departureDate!)) {
      setState(() {
        _message = 'Tanggal pulang tidak boleh sebelum keberangkatan.';
      });
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _message = 'Tidak ada pengguna yang login. Silakan login dahulu.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final tripData = <String, dynamic>{
        'user_id': user.id,
        'trip_name': _tripNameController.text.trim(),
        'trip_type': 'umrah',
        'departure_date': _dateToString(_departureDate!),
        'status': 'preparation',
        if (_returnDate != null) 'return_date': _dateToString(_returnDate!),
        if (_originCityController.text.trim().isNotEmpty)
          'origin_city': _originCityController.text.trim(),
      };

      final savedTrip = await _supabase
          .from('trips')
          .insert(tripData)
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        _message =
            'BERHASIL! Perjalanan tersimpan di Supabase.\n'
            'ID: ${savedTrip['id']}\n'
            'Nama: ${savedTrip['trip_name']}';
      });

      await _loadTrips();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _message =
            'Gagal menyimpan perjalanan.\n'
            'Pesan: ${error.message}\n'
            'Kode: ${error.code ?? '-'}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = 'Terjadi kesalahan: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTrips() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _trips = [];
      });
      return;
    }

    try {
      final result = await _supabase
          .from('trips')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _trips = List<Map<String, dynamic>>.from(result);
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _message =
            'Gagal membaca perjalanan: ${error.message} '
            '(kode ${error.code ?? '-'})';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = 'Gagal membaca perjalanan: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tes Database SafarMate'),
        backgroundColor: const Color(0xFF176B50),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tes Simpan Perjalanan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF176B50),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data akan disimpan ke tabel trips menggunakan '
                'akun yang sedang login.',
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _tripNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama perjalanan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama perjalanan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _originCityController,
                decoration: const InputDecoration(
                  labelText: 'Kota asal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _pickDate(departure: true),
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _departureDate == null
                      ? 'Pilih tanggal keberangkatan'
                      : 'Berangkat: ${_formatDate(_departureDate!)}',
                ),
              ),

              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _pickDate(departure: false),
                icon: const Icon(Icons.event_available),
                label: Text(
                  _returnDate == null
                      ? 'Pilih tanggal pulang (opsional)'
                      : 'Pulang: ${_formatDate(_returnDate!)}',
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTrip,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isLoading ? 'Menyimpan...' : 'Simpan ke Supabase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF176B50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),

              if (_message.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F2E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(_message),
                ),
              ],

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),

              const Text(
                'Perjalanan Tersimpan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadTrips,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat Ulang Data'),
              ),

              if (_trips.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Belum ada perjalanan yang dapat ditampilkan.'),
                ),

              ..._trips.map((trip) {
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.luggage_outlined,
                      color: Color(0xFF176B50),
                    ),
                    title: Text(trip['trip_name']?.toString() ?? '-'),
                    subtitle: Text(
                      'Jenis: ${trip['trip_type'] ?? '-'}\n'
                      'Berangkat: ${trip['departure_date'] ?? '-'}\n'
                      'Status: ${trip['status'] ?? '-'}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
