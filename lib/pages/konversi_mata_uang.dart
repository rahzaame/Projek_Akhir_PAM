import 'package:flutter/material.dart';

import '../services/mata_uang_service.dart';
import '../utils/format_utils.dart';

class CurrencyConverterPage extends StatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  State<CurrencyConverterPage> createState() => _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
  static const Color green = Color(0xFF176B50);
  static const Color lightGreen = Color(0xFFE1F2E8);

  final TextEditingController _amountController = TextEditingController(
    text: '1000000',
  );

  String _from = 'IDR';
  String _to = 'SAR';

  CurrencyRates? _rates;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRates({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rates = await CurrencyService.instance.getRates(
        forceRefresh: force,
      );
      if (!mounted) return;
      setState(() {
        _rates = rates;
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

  double? get _amount => parseAmount(_amountController.text);

  void _swap() {
    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
    });
  }

  String _updatedLabel(CurrencyRates rates) {
    final d = rates.updatedAt;
    final label = '${formatDateShort(d)} ${formatHm(d.hour, d.minute)}';
    return rates.fromCache
        ? 'Kurs tersimpan (offline) • diperbarui $label'
        : 'Kurs terbaru • diperbarui $label';
  }

  @override
  Widget build(BuildContext context) {
    final rates = _rates;
    final amount = _amount;

    double? result;
    String? errorText;
    if (rates != null && amount != null) {
      try {
        result = rates.convert(amount, _from, _to);
      } catch (e) {
        errorText = e.toString();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konversi Mata Uang'),
        actions: [
          IconButton(
            tooltip: 'Perbarui kurs',
            onPressed: _isLoading ? null : () => _loadRates(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading) const LinearProgressIndicator(color: green),

          if (_error != null && rates == null)
            Card(
              color: Colors.red.shade50,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: green),
                      onPressed: () => _loadRates(force: true),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _currencyDropdown('Dari', _from, (v) {
                          setState(() => _from = v);
                        }),
                      ),
                      IconButton(
                        tooltip: 'Tukar',
                        onPressed: _swap,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          color: green,
                        ),
                      ),
                      Expanded(
                        child: _currencyDropdown('Ke', _to, (v) {
                          setState(() => _to = v);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hasil konversi',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        if (errorText != null)
                          Text(errorText)
                        else if (amount == null)
                          const Text('Masukkan jumlah yang valid.')
                        else if (result == null)
                          const Text('Menunggu data kurs…')
                        else ...[
                          Text(
                            '${formatMoney(amount, _from)} =',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            formatMoney(result, _to),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (rates != null) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Kurs hari ini terhadap Rupiah',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
            ),
            for (final c in CurrencyService.currencies.where(
              (c) => c.code != 'IDR',
            ))
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                  title: Text('1 ${c.code}'),
                  subtitle: Text(c.name),
                  trailing: Text(
                    'Rp${formatNumber(rates.idrPerUnit(c.code), decimals: 2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _updatedLabel(rates),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kurs bersifat indikatif. Kurs di tempat penukaran uang '
              'biasanya sedikit berbeda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _currencyDropdown(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'), // paksa rebuild saat nilai ditukar
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      items: [
        for (final c in CurrencyService.currencies)
          DropdownMenuItem(value: c.code, child: Text('${c.flag} ${c.code}')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
