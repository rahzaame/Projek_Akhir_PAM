
import 'package:flutter/foundation.dart';
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

  static const Set<String> supportedCurrencies = {
    'SAR',
    'IDR',
    'USD',
    'TRY',
  };

  String _validateCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();

    if (!supportedCurrencies.contains(normalized)) {
      throw ArgumentError(
        'Mata uang tidak didukung: $currency',
      );
    }

    return normalized;
  }

  Future<Map<String, dynamic>> registerVoucher({
    required String voucherCode,
    required double voucherValue,
    required String voucherCurrency,
    required String documentHash,
  }) async {
    if (!voucherValue.isFinite || voucherValue <= 0) {
      throw ArgumentError(
        'Nominal voucher harus lebih besar dari nol.',
      );
    }

    final currency = _validateCurrency(voucherCurrency);

    final result = await _supabase.rpc(
      'register_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim().toUpperCase(),
        'p_voucher_value': voucherValue,
        'p_voucher_currency': currency,
        'p_document_hash': documentHash,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateVoucher({
    required String voucherCode,
    required double voucherValue,
    required String voucherCurrency,
    required String documentHash,
  }) async {
    if (!voucherValue.isFinite || voucherValue <= 0) {
      throw ArgumentError(
        'Nominal voucher harus lebih besar dari nol.',
      );
    }

    final currency = _validateCurrency(voucherCurrency);

    final result = await _supabase.rpc(
      'update_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim().toUpperCase(),
        'p_voucher_value': voucherValue,
        'p_voucher_currency': currency,
        'p_document_hash': documentHash,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> cancelVoucher({
    required String voucherCode,
  }) async {
    final result = await _supabase.rpc(
      'cancel_voucher_block',
      params: {
        'p_voucher_code': voucherCode.trim().toUpperCase(),
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

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

  Future<List<BlockchainBlock>> getBlocks() async {
    final result = await _supabase.rpc(
      'get_blockchain_history',
    );

    return (result as List)
        .map(
          (row) => BlockchainBlock.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  // Mengambil voucher admin, termasuk mata uang dari database.
  Future<List<Map<String, dynamic>>> getVouchers() async {
    final result = await _supabase.rpc(
      'get_admin_vouchers',
    );

    final vouchers = (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    debugPrint(
      'JUMLAH VOUCHER ADMIN: ${vouchers.length}',
    );

    for (final voucher in vouchers) {
      debugPrint(
        'VOUCHER: ${voucher['voucher_code']} | '
        'CURRENCY: ${voucher['voucher_currency']} | '
        'VALUE: ${voucher['voucher_value']}',
      );
    }

    return vouchers;
  }

  // Mengambil voucher jamaah, termasuk mata uang jika dikembalikan RPC.
  Future<List<Map<String, dynamic>>> getJamaahVouchers() async {
    final result = await _supabase.rpc(
      'get_jamaah_vouchers',
    );

    final vouchers = (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    debugPrint(
      'JUMLAH VOUCHER JAMAAH: ${vouchers.length}',
    );

    for (final voucher in vouchers) {
      debugPrint(
        'VOUCHER JAMAAH: ${voucher['voucher_code']} | '
        'CURRENCY: ${voucher['voucher_currency']} | '
        'VALUE: ${voucher['voucher_value']}',
      );
    }

    return vouchers;
  }
}
