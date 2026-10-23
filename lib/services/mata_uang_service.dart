import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppCurrency {
  final String code;
  final String name;
  final String flag;

  const AppCurrency(this.code, this.name, this.flag);
}

class CurrencyRates {
  final Map<String, double> perIdr;
  final DateTime updatedAt;
  final DateTime fetchedAt;
  final bool fromCache;

  const CurrencyRates({
    required this.perIdr,
    required this.updatedAt,
    required this.fetchedAt,
    required this.fromCache,
  });

  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    final fromRate = perIdr[from];
    final toRate = perIdr[to];
    if (fromRate == null || toRate == null || fromRate == 0) {
      throw const CurrencyException('Kurs untuk mata uang ini belum tersedia.');
    }
    return amount / fromRate * toRate;
  }

  double idrPerUnit(String code) {
    final rate = perIdr[code];
    if (rate == null || rate == 0) {
      throw const CurrencyException('Kurs untuk mata uang ini belum tersedia.');
    }
    return 1 / rate;
  }
}

class CurrencyException implements Exception {
  final String message;
  const CurrencyException(this.message);

  @override
  String toString() => message;
}

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const List<AppCurrency> currencies = [
    AppCurrency('IDR', 'Rupiah Indonesia', '🇮🇩'),
    AppCurrency('SAR', 'Riyal Arab Saudi', '🇸🇦'),
    AppCurrency('TRY', 'Lira Turki', '🇹🇷'),
  ];

  static const String _endpoint = 'https://open.er-api.com/v6/latest/IDR';
  static const String _cacheKey = 'safarmate_currency_cache';
  static const Duration _cacheTtl = Duration(hours: 6);

  CurrencyRates? _memory;

  Future<CurrencyRates> getRates({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _memory ?? await _readCache();
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
        return _memory = cached;
      }
    }

    try {
      return _memory = await _fetchFromApi();
    } catch (_) {
      final cached = _memory ?? await _readCache();
      if (cached != null) {
        return _memory = CurrencyRates(
          perIdr: cached.perIdr,
          updatedAt: cached.updatedAt,
          fetchedAt: cached.fetchedAt,
          fromCache: true,
        );
      }
      throw const CurrencyException(
        'Kurs belum bisa diambil. Periksa koneksi internet lalu coba lagi.',
      );
    }
  }

  Future<CurrencyRates> _fetchFromApi() async {
    final response = await http
        .get(Uri.parse(_endpoint))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw CurrencyException('Server kurs membalas ${response.statusCode}.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['result'] != 'success') {
      throw const CurrencyException('Respons API kurs tidak valid.');
    }

    final rawRates = body['rates'] as Map<String, dynamic>;
    final rates = <String, double>{};
    for (final currency in currencies) {
      final value = rawRates[currency.code];
      if (value is num) rates[currency.code] = value.toDouble();
    }
    rates['IDR'] = 1.0;

    if (currencies.any((c) => !rates.containsKey(c.code))) {
      throw const CurrencyException('Data kurs tidak lengkap.');
    }

    final updatedUnix = body['time_last_update_unix'];
    final updatedAt = updatedUnix is num
        ? DateTime.fromMillisecondsSinceEpoch(
            updatedUnix.toInt() * 1000,
            isUtc: true,
          ).toLocal()
        : DateTime.now();

    final result = CurrencyRates(
      perIdr: rates,
      updatedAt: updatedAt,
      fetchedAt: DateTime.now(),
      fromCache: false,
    );
    await _writeCache(result);
    return result;
  }

  Future<CurrencyRates?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final rates = (json['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      return CurrencyRates(
        perIdr: rates,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updated_at'] as int,
        ),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['fetched_at'] ?? json['updated_at']) as int,
        ),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CurrencyRates rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'rates': rates.perIdr,
          'updated_at': rates.updatedAt.millisecondsSinceEpoch,
          'fetched_at': rates.fetchedAt.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }
}
