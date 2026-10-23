import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/format_utils.dart';
import 'mata_uang_service.dart';

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
  final String currency;
  final double budget;
  final double spent;
  final double budgetIdr;
  final double spentIdr;
  final Map<String, double> byCategory;

  const BudgetSummary({
    required this.currency,
    required this.budget,
    required this.spent,
    required this.budgetIdr,
    required this.spentIdr,
    required this.byCategory,
  });

  double get remaining => budget - spent;
  double get remainingIdr => budgetIdr - spentIdr;
  bool get hasBudget => budget > 0;
  bool get isOverBudget => hasBudget && spent > budget;
  double get usedFraction => hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
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

  String get _budgetKey => 'safarmate_budget_$_userId';
  String get _currencyKey => 'safarmate_budget_currency_$_userId';

  Future<double> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrasi ringan dari versi lama yang menyimpan anggaran dalam IDR.
    return prefs.getDouble(_budgetKey) ??
        prefs.getDouble('safarmate_budget_idr_$_userId') ??
        0;
  }

  Future<String> getBudgetCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? 'IDR';
  }

  Future<void> setBudget(double budget, String currency) async {
    final prefs = await SharedPreferences.getInstance();
    if (budget <= 0) {
      await prefs.remove(_budgetKey);
      await prefs.remove('safarmate_budget_idr_$_userId');
    } else {
      await prefs.setDouble(_budgetKey, budget);
      await prefs.remove('safarmate_budget_idr_$_userId');
    }
    await prefs.setString(_currencyKey, currency);
  }

  Future<void> setBudgetCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency);
  }

  BudgetSummary summarize(
    List<Map<String, dynamic>> expenses,
    double budget,
    String currency,
    CurrencyRates rates,
  ) {
    double spentIdr = 0;
    final categoryIdr = <String, double>{};
    for (final e in expenses) {
      final idr = (e['amount_idr'] as num).toDouble();
      final category = e['category']?.toString() ?? 'Lainnya';
      spentIdr += idr;
      categoryIdr[category] = (categoryIdr[category] ?? 0) + idr;
    }

    final idrPerUnit = currency == 'IDR' ? 1.0 : rates.idrPerUnit(currency);
    final spent = spentIdr / idrPerUnit;
    final budgetIdr = budget * idrPerUnit;
    final byCategory = categoryIdr.map(
      (key, value) => MapEntry(key, value / idrPerUnit),
    );

    return BudgetSummary(
      currency: currency,
      budget: budget,
      spent: _round2(spent),
      budgetIdr: _round2(budgetIdr),
      spentIdr: _round2(spentIdr),
      byCategory: byCategory,
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
