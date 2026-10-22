import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/format_utils.dart';
import 'currency_service.dart';

const List<String> expenseCategories = [
  'Akomodasi',
  'Transportasi',
  'Makanan & Minuman',
  'Belanja',
  'Donasi & Sedekah',
  'Komunikasi',
  'Lainnya',
];

class BudgetSummary {
  final double budgetIdr;
  final double spentIdr;
  final Map<String, double> byCategory;
  final Map<String, double> byCurrency;

  const BudgetSummary({
    required this.budgetIdr,
    required this.spentIdr,
    required this.byCategory,
    required this.byCurrency,
  });

  double get remainingIdr => budgetIdr - spentIdr;
  bool get hasBudget => budgetIdr > 0;
  bool get isOverBudget => hasBudget && spentIdr > budgetIdr;

  double get usedFraction =>
      hasBudget ? (spentIdr / budgetIdr).clamp(0.0, 1.0) : 0.0;
}

class ExpenseService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Silakan login terlebih dahulu.');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final response = await _client
        .from('expenses')
        .select()
        .eq('user_id', _userId)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String currency,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final rate = await _idrRate(currency);

    await _client.from('expenses').insert({
      'user_id': _userId,
      'title': title.trim(),
      'amount': amount,
      'currency': currency,
      'exchange_rate': rate,
      'amount_idr': _round2(amount * rate),
      'category': category,
      'expense_date': toDbDate(date),
      'note': _nullIfEmpty(note),
    });
  }

  Future<void> updateExpense({
    required Map<String, dynamic> original,
    required String title,
    required double amount,
    required String currency,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    final oldAmount = (original['amount'] as num).toDouble();
    final oldCurrency = original['currency'].toString();
    final amountChanged = oldAmount != amount || oldCurrency != currency;

    final double rate = amountChanged
        ? await _idrRate(currency)
        : (original['exchange_rate'] as num).toDouble();

    await _client
        .from('expenses')
        .update({
          'title': title.trim(),
          'amount': amount,
          'currency': currency,
          'exchange_rate': rate,
          'amount_idr': _round2(amount * rate),
          'category': category,
          'expense_date': toDbDate(date),
          'note': _nullIfEmpty(note),
        })
        .eq('id', original['id'])
        .eq('user_id', _userId);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id).eq('user_id', _userId);
  }

  String get _budgetKey => 'safarmate_budget_idr_$_userId';

  Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? 0;
  }

  Future<void> setBudget(double budgetIdr) async {
    final prefs = await SharedPreferences.getInstance();
    if (budgetIdr <= 0) {
      await prefs.remove(_budgetKey);
    } else {
      await prefs.setDouble(_budgetKey, budgetIdr);
    }
  }

  BudgetSummary summarize(List<Map<String, dynamic>> expenses, double budget) {
    double spent = 0;
    final byCategory = <String, double>{};
    final byCurrency = <String, double>{};

    for (final e in expenses) {
      final idr = (e['amount_idr'] as num).toDouble();
      final amount = (e['amount'] as num).toDouble();
      final category = e['category']?.toString() ?? 'Lainnya';
      final currency = e['currency']?.toString() ?? 'IDR';

      spent += idr;
      byCategory[category] = (byCategory[category] ?? 0) + idr;
      byCurrency[currency] = (byCurrency[currency] ?? 0) + amount;
    }

    return BudgetSummary(
      budgetIdr: budget,
      spentIdr: spent,
      byCategory: byCategory,
      byCurrency: byCurrency,
    );
  }

  Future<double> _idrRate(String currency) async {
    if (currency == 'IDR') return 1;
    final rates = await CurrencyService.instance.getRates();
    return rates.idrPerUnit(currency);
  }

  double _round2(double v) => (v * 100).roundToDouble() / 100;

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
