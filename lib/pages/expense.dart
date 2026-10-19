import 'package:flutter/material.dart';

import '../services/currency_service.dart';
import '../services/expense_service.dart';
import '../utils/format_utils.dart';

const Color _green = Color(0xFF176B50);
const Color _lightGreen = Color(0xFFE1F2E8);

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Akomodasi':
      return Icons.hotel_outlined;
    case 'Transportasi':
      return Icons.directions_bus_outlined;
    case 'Makanan & Minuman':
      return Icons.restaurant_outlined;
    case 'Oleh-oleh':
      return Icons.card_giftcard_outlined;
    case 'Belanja':
      return Icons.shopping_bag_outlined;
    case 'Donasi & Sedekah':
      return Icons.volunteer_activism_outlined;
    case 'Komunikasi':
      return Icons.sim_card_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

/// Pencatatan pengeluaran + ringkasan anggaran.
class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final ExpenseService _service = ExpenseService();

  List<Map<String, dynamic>> _expenses = [];
  double _budget = 0;
  bool _isLoading = true;
  String? _error;
  String? _categoryFilter; // null = semua

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchExpenses(),
        _service.getBudget(),
      ]);
      if (!mounted) return;
      setState(() {
        _expenses = results[0] as List<Map<String, dynamic>>;
        _budget = results[1] as double;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------- BUDGET
  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: _budget > 0 ? _budget.toStringAsFixed(0) : '',
    );

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anggaran Perjalanan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Total anggaran (Rupiah)',
            prefixText: 'Rp ',
            border: OutlineInputBorder(),
            helperText: 'Kosongkan untuk menghapus anggaran',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () =>
                Navigator.pop(dialogContext, parseAmount(controller.text) ?? 0),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (value == null || !mounted) return;
    await _service.setBudget(value);
    if (!mounted) return;
    setState(() => _budget = value < 0 ? 0 : value);
  }

  // ---------------------------------------------------------------- CRUD
  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpenseFormSheet(service: _service, existing: existing),
    );
    if (saved != true || !mounted) return;
    _snack(
      existing == null ? 'Pengeluaran dicatat.' : 'Pengeluaran diperbarui.',
    );
    await _load();
  }

  Future<bool> _confirmDelete(Map<String, dynamic> expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus pengeluaran?'),
        content: Text('“${expense['title']}” akan dihapus dari catatan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await _service.deleteExpense(expense['id'].toString());
      if (!mounted) return false;
      _snack('Pengeluaran dihapus.');
      return true;
    } catch (e) {
      if (mounted) _snack('Gagal menghapus: $e');
      return false;
    }
  }

  // --------------------------------------------------------------- BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Pengeluaran')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 56, color: _green),
              const SizedBox(height: 12),
              const Text(
                'Pengeluaran gagal dimuat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: _load,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _service.summarize(_expenses, _budget);
    final filtered = _categoryFilter == null
        ? _expenses
        : _expenses.where((e) => e['category'] == _categoryFilter).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _summaryCard(summary),
          if (summary.byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _categoryBreakdown(summary),
          ],
          const SizedBox(height: 16),
          _filterChips(summary),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 52, color: _green),
                  SizedBox(height: 10),
                  Text(
                    'Belum ada pengeluaran',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tekan Catat untuk menambahkan pengeluaran pertamamu.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final e in filtered) _expenseTile(e),
        ],
      ),
    );
  }

  // ------------------------------------------------------ RINGKASAN
  Widget _summaryCard(BudgetSummary s) {
    final over = s.isOverBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: over
              ? [const Color(0xFFB3261E), const Color(0xFFD9645C)]
              : [const Color(0xFF176B50), const Color(0xFF399477)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ringkasan Anggaran',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _editBudget,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(s.hasBudget ? 'Ubah' : 'Atur'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Total pengeluaran',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            formatMoney(s.spentIdr, 'IDR'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),
          if (s.hasBudget) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: s.usedFraction,
                minHeight: 10,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFB8F0D0)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    'Anggaran',
                    formatMoney(s.budgetIdr, 'IDR'),
                  ),
                ),
                Expanded(
                  child: _summaryItem(
                    over ? 'Melebihi anggaran' : 'Sisa anggaran',
                    formatMoney(s.remainingIdr.abs(), 'IDR'),
                  ),
                ),
              ],
            ),
            if (over)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Pengeluaranmu sudah melewati anggaran.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ] else
            const Text(
              'Atur anggaran perjalanan untuk melihat sisa anggaranmu.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (s.byCurrency.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in s.byCurrency.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatMoney(entry.value, entry.key),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _categoryBreakdown(BudgetSummary s) {
    final entries = s.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengeluaran per kategori',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(_categoryIcon(e.key), size: 18, color: _green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key)),
                        Text(
                          formatMoney(e.value, 'IDR'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: s.spentIdr == 0 ? 0 : e.value / s.spentIdr,
                        minHeight: 6,
                        backgroundColor: _lightGreen,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips(BudgetSummary s) {
    final categories = s.byCategory.keys.toList()..sort();
    if (categories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: _categoryFilter == null,
              onSelected: (_) => setState(() => _categoryFilter = null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c),
                selected: _categoryFilter == c,
                onSelected: (_) => setState(() => _categoryFilter = c),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- DAFTAR
  Widget _expenseTile(Map<String, dynamic> e) {
    final currency = e['currency']?.toString() ?? 'IDR';
    final amount = (e['amount'] as num).toDouble();
    final amountIdr = (e['amount_idr'] as num).toDouble();
    final date = parseDbDate(e['expense_date']);
    final category = e['category']?.toString() ?? 'Lainnya';
    final note = e['note']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(e['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(e),
      onDismissed: (_) {
        setState(() => _expenses.removeWhere((x) => x['id'] == e['id']));
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          onTap: () => _openForm(existing: e),
          leading: CircleAvatar(
            backgroundColor: _lightGreen,
            child: Icon(_categoryIcon(category), color: _green, size: 22),
          ),
          title: Text(
            e['title']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '$category • ${date != null ? formatDateShort(date) : '-'}'
            '${note.isNotEmpty ? '\n$note' : ''}',
          ),
          isThreeLine: note.isNotEmpty,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(amount, currency),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (currency != 'IDR')
                Text(
                  '≈ ${formatMoney(amountIdr, 'IDR')}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  FORM TAMBAH / UBAH PENGELUARAN
// =====================================================================
class _ExpenseFormSheet extends StatefulWidget {
  final ExpenseService service;
  final Map<String, dynamic>? existing;

  const _ExpenseFormSheet({required this.service, this.existing});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  late String _currency;
  late String _category;
  late DateTime _date;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _title = TextEditingController(text: e?['title']?.toString() ?? '');
    _note = TextEditingController(text: e?['note']?.toString() ?? '');

    if (e == null) {
      _amount = TextEditingController();
      _currency = 'SAR';
      _category = expenseCategories.first;
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
    } else {
      final amount = (e['amount'] as num).toDouble();
      _amount = TextEditingController(
        text: amount == amount.roundToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toString(),
      );
      _currency = e['currency']?.toString() ?? 'IDR';
      _category = expenseCategories.contains(e['category'])
          ? e['category'].toString()
          : 'Lainnya';
      _date = parseDbDate(e['expense_date']) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final amount = parseAmount(_amount.text)!;
      final existing = widget.existing;

      if (existing == null) {
        await widget.service.addExpense(
          title: _title.text,
          amount: amount,
          currency: _currency,
          category: _category,
          date: _date,
          note: _note.text,
        );
      } else {
        await widget.service.updateExpense(
          original: existing,
          title: _title.text,
          amount: amount,
          currency: _currency,
          category: _category,
          date: _date,
          note: _note.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'Ubah Pengeluaran' : 'Catat Pengeluaran',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _green,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Contoh: Makan siang di Makkah',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Keterangan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final parsed = parseAmount(v ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Nominal tidak valid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Mata uang',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in CurrencyService.currencies)
                          DropdownMenuItem(value: c.code, child: Text(c.code)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in expenseCategories)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(_categoryIcon(c), size: 18, color: _green),
                          const SizedBox(width: 10),
                          Text(c),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('Tanggal: ${formatDateShort(_date)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_currency != 'IDR')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Nilai rupiah dihitung otomatis dari kurs terbaru.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(editing ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
