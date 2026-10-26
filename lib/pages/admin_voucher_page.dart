import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/blockchain_service.dart';
import '../services/trip_service.dart';
import '../services/voucher_document_service.dart';
import 'admin_voucher_list_page.dart';

class AdminVoucherPage extends StatefulWidget {
  const AdminVoucherPage({super.key});

  @override
  State<AdminVoucherPage> createState() => _AdminVoucherPageState();
}

class _AdminVoucherPageState extends State<AdminVoucherPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();

  String _selectedCurrency = 'IDR';

  final List<String> _currencies = ['IDR', 'SAR', 'TRY'];

  final _documentService = VoucherDocumentService();
  final _blockchainService = BlockchainService();

  final _tripService = TripService();

  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _selectedTrip;

  VoucherPdfData? _pdf;
  bool _loading = false;
  String? _message;
  bool? _messageIsSuccess;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final rows = await _tripService.fetchAllTrips();
      if (!mounted) return;
      setState(() {
        _trips = rows.where((t) => t['status'] != 'cancelled').toList();
      });
    } catch (_) {
      // Kebijakan admin belum dibuat: voucher tetap bisa didaftarkan tanpa tautan.
    }
  }

  Future<void> _removeUploaded(String? path) async {
    if (path == null) return;
    try {
      await Supabase.instance.client.storage.from('voucher-pdfs').remove([
        path,
      ]);
    } catch (_) {
      // Pembersihan gagal tidak boleh menutupi pesan error utama.
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final pdf = await _documentService.pickPdf();
      if (!mounted || pdf == null) return;

      setState(() {
        _pdf = pdf;
        _message = 'PDF dipilih: ${pdf.fileName}';
        _messageIsSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Gagal membaca PDF: $e';
        _messageIsSuccess = false;
      });
    }
  }

  Future<void> _registerVoucher() async {
    String? uploadedPath;

    if (!_formKey.currentState!.validate()) return;

    if (_pdf == null) {
      setState(() {
        _message = 'Pilih PDF voucher terlebih dahulu.';
        _messageIsSuccess = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final value = double.parse(
        _valueController.text.trim().replaceAll(',', '.'),
      );

      final code = _codeController.text.trim().toUpperCase();
      final currency = _selectedCurrency;
      final pdf = _pdf!;

      // Upload PDF voucher ke Supabase Storage.
      final storagePath = '$code.pdf';

      await Supabase.instance.client.storage
          .from('voucher-pdfs')
          .uploadBinary(
            storagePath,
            pdf.bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      uploadedPath = storagePath;

      // Simpan data voucher dan mata uang ke blockchain.
      final result = await _blockchainService.registerVoucher(
        voucherCode: code,
        voucherValue: value,
        voucherCurrency: currency,
        documentHash: pdf.hash,
      );

      if (!mounted) {
        // Jika widget sudah ditutup, bersihkan file bila registrasi gagal.
        if (result['success'] != true) {
          await _removeUploaded(uploadedPath);
        }
        return;
      }

      final success = result['success'] == true;

      var linkNote = '';

      if (!success) {
        // Registrasi blockchain gagal: hapus PDF yang sudah diupload.
        await _removeUploaded(uploadedPath);
        uploadedPath = null;
      } else if (_selectedTrip != null) {
        try {
          await _tripService.linkVoucher(
            voucherCode: code,
            trip: _selectedTrip!,
          );

          linkNote =
              ' Voucher dikaitkan ke '
              '${_selectedTrip!['customer_name'] ?? 'pemesanan'}.';
        } catch (e) {
          linkNote = ' Namun voucher gagal dikaitkan ke pemesanan: $e';
        }
      }

      if (!mounted) return;

      setState(() {
        _message = success
            ? 'Voucher berhasil disimpan. '
                  'Nominal: $currency ${value.toStringAsFixed(2)}. '
                  'Indeks blok: ${result['block_index']}.$linkNote'
            : 'Registrasi gagal: '
                  '${result['message'] ?? 'Kesalahan tidak diketahui'}';

        _messageIsSuccess = success;
      });

      if (success) {
        _codeController.clear();
        _valueController.clear();

        setState(() {
          _pdf = null;
          _selectedTrip = null;
          _selectedCurrency = 'SAR';
        });
      }
    } catch (e) {
      // Hapus file yang sempat diupload jika proses mengalami error.
      await _removeUploaded(uploadedPath);

      if (!mounted) return;

      setState(() {
        _message = 'Gagal mendaftarkan voucher: $e';
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyPdf() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final pdf = await _documentService.pickPdf();
      if (!mounted || pdf == null) return;

      final result = await _blockchainService.verifyDocument(pdf.hash);
      if (!mounted) return;

      final valid = result['valid'] == true;
      setState(() {
        _message = valid
            ? 'PDF VALID. Kode voucher: ${result['voucher_code']}. '
                  'Status: ${result['voucher_status']}.'
            : 'PDF TIDAK COCOK: ${result['message']}';
        _messageIsSuccess = valid;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Verifikasi gagal: $e';
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF287653);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Voucher Blockchain'),
        actions: [
          IconButton(
            tooltip: 'Daftar Voucher',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminVoucherListPage()),
              );
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.verified_user, size: 60, color: green),
          const SizedBox(height: 12),
          const Text(
            'Registrasi dan Verifikasi Voucher',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kode voucher
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kode voucher',
                    hintText: 'Contoh: VCR001',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Kode voucher wajib diisi';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Dropdown mata uang
                DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mata uang',
                    prefixIcon: Icon(Icons.currency_exchange),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'IDR',
                      child: Text('IDR - Rupiah Indonesia'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'SAR',
                      child: Text('SAR - Riyal Saudi'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'TRY',
                      child: Text('TRY - Lira Turki'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (currency) {
                          if (currency == null) return;
                          setState(() {
                            _selectedCurrency = currency;
                          });
                        },
                ),

                const SizedBox(height: 14),

                // Nominal voucher
                TextFormField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nominal voucher',
                    hintText: 'Masukkan nominal',
                    prefixText: '$_selectedCurrency ',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final input = (v ?? '').trim().replaceAll(',', '.');
                    final value = double.tryParse(input);

                    if (input.isEmpty ||
                        value == null ||
                        !value.isFinite ||
                        value <= 0) {
                      return 'Masukkan nominal yang valid';
                    }

                    return null;
                  },
                ),

                // Pemesanan opsional
                if (_trips.isNotEmpty) ...[
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String?>(
                    key: ValueKey(_selectedTrip?['id']),
                    initialValue: _selectedTrip?['id']?.toString(),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kaitkan ke pemesanan (opsional)',
                      helperText:
                          'Jamaah pemilik pemesanan akan melihat voucher ini.',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tidak dikaitkan'),
                      ),
                      ..._trips.map(
                        (trip) => DropdownMenuItem<String?>(
                          value: trip['id'].toString(),
                          child: Text(
                            '${trip['customer_name'] ?? 'Tanpa nama'} · '
                            '${trip['trip_name'] ?? '-'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _loading
                        ? null
                        : (id) {
                            setState(() {
                              _selectedTrip = id == null
                                  ? null
                                  : _trips.firstWhere(
                                      (trip) => trip['id'].toString() == id,
                                    );
                            });
                          },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickPdf,
            icon: const Icon(Icons.upload_file),
            label: Text(_pdf == null ? 'Pilih PDF Voucher' : _pdf!.fileName),
          ),
          if (_pdf != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Hash SHA-256:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(_pdf!.hash, style: const TextStyle(fontSize: 11)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _registerVoucher,
            icon: const Icon(Icons.add_link),
            label: const Text('Daftarkan Voucher'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _verifyPdf,
            icon: const Icon(Icons.fact_check),
            label: const Text('Verifikasi PDF'),
          ),
          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_message != null) ...[
            const SizedBox(height: 20),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsSuccess == true ? green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
