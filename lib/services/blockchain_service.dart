
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return BlockchainBlock(
      index: (map['block_index'] as num).toInt(),
      activity: map['activity']?.toString() ?? '',
      timestamp: DateTime.parse(map['created_at'].toString()),
      previousHash: map['previous_hash']?.toString() ?? '',
      hash: map['hash']?.toString() ?? '',
      eventType: map['event_type']?.toString(),
    );
  }
}

class BlockchainService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // CREATE: mendaftarkan voucher baru melalui RPC.
  Future<Map<String, dynamic>> registerVoucher({
    required String voucherCode,
    required double voucherValue,
    required String documentHash,
  }) async {
    final result = await _supabase.rpc(
      'register_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim(),
        'p_voucher_value': voucherValue,
        'p_document_hash': documentHash,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  // UPDATE: memperbarui voucher melalui RPC.
  // Fungsi update_voucher_block harus sudah dibuat di Supabase.
  Future<Map<String, dynamic>> updateVoucher({
    required String voucherCode,
    required double voucherValue,
    required String documentHash,
  }) async {
    final result = await _supabase.rpc(
      'update_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim(),
        'p_voucher_value': voucherValue,
        'p_document_hash': documentHash,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  // CANCEL: membatalkan voucher tanpa menghapus riwayat blockchain.
  // Fungsi cancel_voucher_block harus sudah dibuat di Supabase.
  Future<Map<String, dynamic>> cancelVoucher({
    required String voucherCode,
  }) async {
    final result = await _supabase.rpc(
      'cancel_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim(),
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  // VERIFY: memverifikasi PDF berdasarkan hash SHA-256.
  Future<Map<String, dynamic>> verifyDocument(
    String documentHash,
  ) async {
    final result = await _supabase.rpc(
      'verify_voucher_document',
      params: {
        'p_document_hash': documentHash,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  // READ: mengambil riwayat blockchain.
  Future<List<BlockchainBlock>> getBlocks() async {
    final result = await _supabase.rpc('get_blockchain_history');

    return (result as List)
        .map(
          (row) => BlockchainBlock.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  // READ ADMIN: mengambil daftar voucher untuk halaman admin.
  Future<List<Map<String, dynamic>>> getVouchers() async {
    final result = await _supabase.rpc('get_admin_vouchers');

    return (result as List)
        .map(
          (row) => Map<String, dynamic>.from(row as Map),
        )
        .toList();
  }

  // READ JAMAAH: mengambil daftar voucher yang boleh dilihat jamaah.
  // RPC Supabase mengembalikan block_index, created_at,
  // voucher_code, voucher_value, dan voucher_status.
  Future<List<Map<String, dynamic>>> getJamaahVouchers() async {
    final result = await _supabase.rpc('get_jamaah_vouchers');

    return (result as List)
        .map(
          (row) => Map<String, dynamic>.from(row as Map),
        )
        .toList();
  }
}
