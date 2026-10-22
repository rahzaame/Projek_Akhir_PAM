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

      final code = _codeController.text.trim();
      final pdf = _pdf!;

      // Simpan PDF di Supabase Storage terlebih dahulu.
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

      // Catat hash dokumen ke blockchain.
      final result = await _blockchainService.registerVoucher(
        voucherCode: code,
        voucherValue: value,
        documentHash: pdf.hash,
      );

      if (!mounted) return;

      final success = result['success'] == true;

      setState(() {
        _message = success
            ? 'Voucher berhasil disimpan. Indeks blok: ${result['block_index']}'
            : 'Registrasi gagal: ${result['message'] ?? 'Kesalahan tidak diketahui'}';
        _messageIsSuccess = success;
      });

      if (success) {
        _codeController.clear();
        _valueController.clear();
        setState(() => _pdf = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Gagal mendaftarkan voucher: $e';
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode voucher',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Kode voucher wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nominal voucher',
                    prefixText: 'SAR ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    if (value == null || value <= 0) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                ),
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
