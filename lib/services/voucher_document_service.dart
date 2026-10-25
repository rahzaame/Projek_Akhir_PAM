import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

class VoucherPdfData {
  final String fileName;
  final Uint8List bytes;
  final String hash;

  const VoucherPdfData({
    required this.fileName,
    required this.bytes,
    required this.hash,
  });
}

class VoucherDocumentService {
  Future<VoucherPdfData?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (file == null) return null;

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('File PDF tidak dapat dibaca.');
    }

    return VoucherPdfData(
      fileName: file.name,
      bytes: bytes,
      hash: sha256.convert(bytes).toString(),
    );
  }
}
