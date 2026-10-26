import 'package:supabase_flutter/supabase_flutter.dart';

/// Representasi satu blok blockchain yang dikembalikan oleh RPC history.
class BlockchainBlock {
  final int index;
  final String activity;
  final DateTime timestamp;
  final String previousHash;
  final String hash;
  final String? eventType;

  const BlockchainBlock({
    required this.index,
    required this.activity,
    required this.timestamp,
    required this.previousHash,
    required this.hash,
    this.eventType,
  });

  factory BlockchainBlock.fromMap(Map<String, dynamic> map) {
    final rawIndex = map['block_index'];
    final rawTimestamp = map['created_at'];

    return BlockchainBlock(
      index: rawIndex is num ? rawIndex.toInt() : int.tryParse('$rawIndex') ?? 0,
      activity: map['activity']?.toString() ?? '',
      timestamp: DateTime.tryParse(rawTimestamp?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      previousHash: map['previous_hash']?.toString() ?? '',
      hash: map['hash']?.toString() ?? '',
      eventType: map['event_type']?.toString(),
    );
  }
}

/// Akses RPC Supabase untuk voucher dan riwayat blockchain.
///
/// Catatan:
/// - Nama RPC dan nama parameter harus sama persis dengan yang ada di Supabase.
/// - Service ini tidak membuat atau mengubah fungsi SQL di database.
class BlockchainService {
  final SupabaseClient _supabase;

  BlockchainService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Map<String, dynamic> _asMap(dynamic result, String rpcName) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw FormatException(
      'Respons RPC "$rpcName" bukan objek JSON yang valid.',
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic result, String rpcName) {
    if (result is! List) {
      throw FormatException(
        'Respons RPC "$rpcName" bukan daftar data yang valid.',
      );
    }

    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // CREATE: mendaftarkan voucher melalui register_voucher_block.
  // Nama toko dan alamat dikirim sebagai parameter tambahan.
  // Pastikan signature RPC SQL menerima kedua parameter ini.
  Future<Map<String, dynamic>> registerVoucher({
    required String voucherCode,
    required double voucherValue,
    required String voucherCurrency,
    required String documentHash,
    required String voucherStoreName,
    required String voucherStoreAddress,
  }) async {
    final code = voucherCode.trim().toUpperCase();
    final storeName = voucherStoreName.trim();
    final storeAddress = voucherStoreAddress.trim();

    if (code.isEmpty) {
      throw ArgumentError('Kode voucher tidak boleh kosong.');
    }
    if (!voucherValue.isFinite || voucherValue <= 0) {
      throw ArgumentError('Nominal voucher harus lebih besar dari 0.');
    }
    if (voucherCurrency.trim().isEmpty) {
      throw ArgumentError('Mata uang voucher harus dipilih.');
    }
    if (documentHash.trim().isEmpty) {
      throw ArgumentError('Hash dokumen tidak boleh kosong.');
    }
    if (storeName.isEmpty) {
      throw ArgumentError('Nama toko tidak boleh kosong.');
    }
    if (storeAddress.isEmpty) {
      throw ArgumentError('Alamat toko tidak boleh kosong.');
    }

    final result = await _supabase.rpc(
      'register_voucher_block',
      params: {
        'p_voucher_code': code,
        'p_voucher_value': voucherValue,
        'p_voucher_currency': voucherCurrency.trim().toUpperCase(),
        'p_document_hash': documentHash.trim(),
        'p_voucher_store_name': storeName,
        'p_voucher_store_address': storeAddress,
      },
    );

    return _asMap(result, 'register_voucher_block');
  }

  // UPDATE: memperbarui voucher melalui update_voucher_block.
  // Signature RPC yang dipakai di sini mengikuti parameter yang sudah ada.
  Future<Map<String, dynamic>> updateVoucher({
    required String voucherCode,
    required double voucherValue,
    required String documentHash,
  }) async {
    final code = voucherCode.trim().toUpperCase();

    if (code.isEmpty) {
      throw ArgumentError('Kode voucher tidak boleh kosong.');
    }
    if (!voucherValue.isFinite || voucherValue <= 0) {
      throw ArgumentError('Nominal voucher harus lebih besar dari 0.');
    }
    if (documentHash.trim().isEmpty) {
      throw ArgumentError('Hash dokumen tidak boleh kosong.');
    }

    final result = await _supabase.rpc(
      'update_voucher_block',
      params: {
        'p_voucher_code': code,
        'p_voucher_value': voucherValue,
        'p_document_hash': documentHash.trim(),
      },
    );

    return _asMap(result, 'update_voucher_block');
  }

  // CANCEL: membatalkan voucher tanpa menghapus riwayat blockchain.
  Future<Map<String, dynamic>> cancelVoucher({
    required String voucherCode,
  }) async {
    final code = voucherCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw ArgumentError('Kode voucher tidak boleh kosong.');
    }

    final result = await _supabase.rpc(
      'cancel_voucher_block',
      params: {'p_voucher_code': code},
    );

    return _asMap(result, 'cancel_voucher_block');
  }

  // VERIFY: memverifikasi PDF berdasarkan hash SHA-256.
  Future<Map<String, dynamic>> verifyDocument(String documentHash) async {
    final hash = documentHash.trim();
    if (hash.isEmpty) {
      throw ArgumentError('Hash dokumen tidak boleh kosong.');
    }

    final result = await _supabase.rpc(
      'verify_voucher_document',
      params: {'p_document_hash': hash},
    );

    return _asMap(result, 'verify_voucher_document');
  }

  // READ: mengambil riwayat blockchain.
  Future<List<BlockchainBlock>> getBlocks() async {
    final result = await _supabase.rpc('get_blockchain_history');
    final rows = _asMapList(result, 'get_blockchain_history');

    return rows.map(BlockchainBlock.fromMap).toList();
  }

  // READ ADMIN: daftar voucher admin, termasuk mata uang dan lokasi
  // jika RPC get_admin_vouchers_with_currency mengembalikannya.
  Future<List<Map<String, dynamic>>> getVouchers() async {
    final result =
        await _supabase.rpc('get_admin_vouchers_with_currency');
    return _asMapList(result, 'get_admin_vouchers_with_currency');
  }

  // READ JAMAAH: daftar voucher yang dapat dilihat jamaah.
  Future<List<Map<String, dynamic>>> getJamaahVouchers() async {
    final result = await _supabase.rpc('get_jamaah_vouchers');
    return _asMapList(result, 'get_jamaah_vouchers');
  }
}
