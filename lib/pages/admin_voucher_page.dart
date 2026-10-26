import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/blockchain_service.dart';
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
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  

  String _selectedCurrency = 'IDR';

  final _documentService = VoucherDocumentService();
  final _blockchainService = BlockchainService();

  VoucherPdfData? _pdf;

  bool _loading = false;
  String? _message;
  bool? _messageIsSuccess;

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    super.dispose();
  }

  // ============================================================
  // PILIH PDF
  // ============================================================

  Future<void> _pickPdf() async {
    if (_loading) return;

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

  // ============================================================
  // DAFTARKAN VOUCHER
  // ============================================================

  Future<void> _registerVoucher() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      _messageIsSuccess = null;
    });

    try {
      final value = double.parse(
        _valueController.text.trim().replaceAll(',', '.'),
      );

      final code = _codeController.text.trim().toUpperCase();
      final currency = _selectedCurrency;
      final storeName = _storeNameController.text.trim();
      final storeAddress = _storeAddressController.text.trim();
      final pdf = _pdf!;

      // ========================================================
      // 1. UPLOAD PDF KE SUPABASE STORAGE
      // ========================================================

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

      // ========================================================
      // 2. SIMPAN DATA VOUCHER KE BLOCKCHAIN
      // ========================================================

      final result = await _blockchainService.registerVoucher(
        voucherCode: code,
        voucherValue: value,
        voucherCurrency: currency,
        documentHash: pdf.hash,
        voucherStoreName: _storeNameController.text.trim(),
        voucherStoreAddress: _storeAddressController.text.trim(),
      );

      if (!mounted) return;

      final success = result['success'] == true;

      if (success) {
        setState(() {
          _message =
              'Voucher berhasil didaftarkan.\n'
              'Kode: $code\n'
              'Nominal: $currency ${_formatNumber(value)}\n'
              'Indeks blok: ${result['block_index'] ?? '-'}';
          _messageIsSuccess = true;
        });

        // Reset form setelah berhasil.
        _codeController.clear();
        _valueController.clear();
        _storeNameController.clear();
        _storeAddressController.clear();

        setState(() {
          _pdf = null;
          _selectedCurrency = 'SAR';
        });
      } else {
        setState(() {
          _message =
              'Registrasi gagal: '
              '${result['message'] ?? 'Kesalahan tidak diketahui.'}';
          _messageIsSuccess = false;
        });
      }
    } on StorageException catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Gagal mengunggah PDF: ${e.message}';
        _messageIsSuccess = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Gagal mendaftarkan voucher: $e';
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // VERIFIKASI PDF
  // ============================================================

  Future<void> _verifyPdf() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _message = null;
      _messageIsSuccess = null;
    });

    try {
      final pdf = await _documentService.pickPdf();

      if (!mounted || pdf == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final result = await _blockchainService.verifyDocument(pdf.hash);

      if (!mounted) return;

      final valid = result['valid'] == true;

      if (valid) {
        final voucherCode = result['voucher_code']?.toString() ?? '-';

        final status = result['voucher_status']?.toString() ?? '-';

        final blockIndex = result['block_index']?.toString() ?? '-';

        setState(() {
          _message =
              'PDF VALID.\n'
              'Kode voucher: $voucherCode\n'
              'Status: $status\n'
              'Blok: $blockIndex';
          _messageIsSuccess = true;
        });
      } else {
        setState(() {
          _message =
              'PDF TIDAK COCOK.\n'
              '${result['message'] ?? 'Dokumen tidak terdaftar.'}';
          _messageIsSuccess = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Verifikasi gagal: $e';
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT NOMINAL
  // ============================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // BUILD
  // ============================================================

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
            onPressed: _loading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminVoucherListPage(),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            const Icon(Icons.verified_user, size: 60, color: green),

            const SizedBox(height: 12),

            const Text(
              'Registrasi dan Verifikasi Voucher',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Data voucher akan dicatat ke blockchain '
              'dengan hash SHA-256.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // KODE VOUCHER
            // ==================================================
            TextFormField(
              controller: _codeController,
              enabled: !_loading,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kode voucher',
                hintText: 'Contoh: SAFAR-MKH-003',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final code = value?.trim() ?? '';

                if (code.isEmpty) {
                  return 'Kode voucher wajib diisi';
                }

                if (code.length < 3) {
                  return 'Kode voucher minimal 3 karakter';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            // ==================================================
            // MATA UANG + NOMINAL
            // ==================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 115,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Mata uang',
                      prefixIcon: Icon(Icons.currency_exchange),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'IDR', child: Text('IDR')),
                      DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                      DropdownMenuItem(value: 'TRY', child: Text('TRY')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCurrency = value;
                        });
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller: _valueController,
                    enabled: !_loading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nominal voucher',
                      hintText: 'Contoh: 500',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim().replaceAll(',', '.');

                      final number = double.tryParse(text);

                      if (text.isEmpty) {
                        return 'Nominal wajib diisi';
                      }

                      if (number == null) {
                        return 'Nominal tidak valid';
                      }

                      if (number <= 0) {
                        return 'Nominal harus lebih dari 0';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Mata uang yang dipilih: $_selectedCurrency',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // INFORMASI TOKO
            // ==================================================
            const Text(
              'Informasi Toko',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _storeNameController,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama toko',
                hintText: 'Contoh: Al Noor Store',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Nama toko wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _storeAddressController,
              enabled: !_loading,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Alamat lengkap toko',
                hintText: 'Nama jalan, kota, negara',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Alamat toko wajib diisi';
                }
                if ((value ?? '').trim().length < 8) {
                  return 'Masukkan alamat yang lebih lengkap';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ==================================================
            // PDF
            // ==================================================
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.picture_as_pdf),
                        SizedBox(width: 8),
                        Text(
                          'Dokumen Voucher',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pickPdf,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _pdf == null
                              ? 'Pilih PDF Voucher'
                              : 'Ganti PDF Voucher',
                        ),
                      ),
                    ),

                    if (_pdf != null) ...[
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'File terpilih',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              _pdf!.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'SHA-256',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 4),

                            SelectableText(
                              _pdf!.hash,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // DAFTARKAN
            // ==================================================
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _registerVoucher,
                icon: const Icon(Icons.add_link),
                label: const Text(
                  'Daftarkan Voucher',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // VERIFIKASI
            // ==================================================
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _verifyPdf,
                icon: const Icon(Icons.fact_check),
                label: const Text(
                  'Verifikasi PDF',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // ==================================================
            // LOADING
            // ==================================================
            if (_loading) ...[
              const SizedBox(height: 20),

              const Center(child: CircularProgressIndicator()),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'Sedang memproses...',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],

            // ==================================================
            // MESSAGE
            // ==================================================
            if (_message != null) ...[
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_messageIsSuccess == true ? Colors.green : Colors.red)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        (_messageIsSuccess == true ? Colors.green : Colors.red)
                            .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _messageIsSuccess == true
                          ? Icons.check_circle
                          : Icons.error,
                      color: _messageIsSuccess == true
                          ? Colors.green
                          : Colors.red,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _messageIsSuccess == true
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
