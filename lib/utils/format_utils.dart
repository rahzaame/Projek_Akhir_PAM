library;

const List<String> _bulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _bulanSingkat = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const List<String> _hari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String formatNumber(num value, {int decimals = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];

  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    buffer.write(intPart[i]);
    final remaining = intPart.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }

  final decimalPart = decimals > 0 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$buffer$decimalPart';
}

String formatMoney(num value, String currency) {
  if (currency == 'IDR') return 'Rp${formatNumber(value)}';
  return '$currency ${formatNumber(value, decimals: 2)}';
}

String toDbDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String toDbTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}:00';

String formatDate(DateTime date) =>
    '${date.day} ${_bulan[date.month - 1]} ${date.year}';

String formatDateShort(DateTime date) =>
    '${date.day} ${_bulanSingkat[date.month - 1]} ${date.year}';

String formatDateLong(DateTime date) =>
    '${_hari[date.weekday - 1]}, ${formatDate(date)}';

String formatHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

DateTime? parseDbDate(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

({int hour, int minute})? parseDbTime(dynamic value) {
  if (value == null) return null;
  final parts = value.toString().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return (hour: h, minute: m);
}

double? parseAmount(String input) {
  var text = input.trim().replaceAll(' ', '');
  if (text.isEmpty) return null;

  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (text.contains('.')) {
    final parts = text.split('.');
    final looksDecimal = parts.length == 2 && parts[1].length <= 2;
    if (!looksDecimal) text = text.replaceAll('.', '');
  }
  return double.tryParse(text);
}
