import 'dart:async';

import 'package:flutter/material.dart';

import '../services/zona_waktu_service.dart';
import '../utils/format_utils.dart';

class TimeConverterPage extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialZoneId;

  const TimeConverterPage({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialZoneId,
  });

  @override
  State<TimeConverterPage> createState() => _TimeConverterPageState();
}

class _TimeConverterPageState extends State<TimeConverterPage> {
  static const Color green = Color(0xFF176B50);
  static const Color lightGreen = Color(0xFFE1F2E8);

  late String _sourceZoneId;
  late DateTime _date;
  late TimeOfDay _time;

  bool _live = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    TimezoneService.ensureInitialized();

    _sourceZoneId = widget.initialZoneId ?? TimezoneService.zones.first.tzId;

    if (widget.initialDate != null && widget.initialTime != null) {
      _date = widget.initialDate!;
      _time = widget.initialTime!;
    } else {
      _live = true;
      _syncToNow();
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_live) return;
      setState(_syncToNow);
    });
  }

  void _syncToNow() {
    final now = TimezoneService.nowIn(_sourceZoneId);
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  void _setLive(bool value) {
    setState(() {
      _live = value;
      if (value) {
        _syncToNow();
        _startTicker();
      } else {
        _ticker?.cancel();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _live = false;
      _ticker?.cancel();
      _date = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _live = false;
      _ticker?.cancel();
      _time = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = TimezoneService.wallTime(
      _sourceZoneId,
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final results = TimezoneService.convertToAll(source);

    return Scaffold(
      appBar: AppBar(title: const Text('Konversi Zona Waktu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Waktu yang dikonversi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_sourceZoneId),
                    initialValue: _sourceZoneId,
                    decoration: const InputDecoration(
                      labelText: 'Zona asal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public, color: green),
                    ),
                    items: [
                      for (final z in TimezoneService.zones)
                        DropdownMenuItem(
                          value: z.tzId,
                          child: Text('${z.code} • ${z.note}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sourceZoneId = value;
                        if (_live) _syncToNow();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(formatDateShort(_date)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(formatHm(_time.hour, _time.minute)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: green,
                    title: const Text('Gunakan waktu sekarang'),
                    subtitle: const Text('Jam berjalan otomatis'),
                    value: _live,
                    onChanged: _setLive,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Perbandingan waktu',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: green,
              ),
            ),
          ),
          for (final r in results) _zoneTile(r),
          const SizedBox(height: 8),
          const Card(
            elevation: 0,
            color: Color(0xFFFFF4D8),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneTile(ZoneTime r) {
    final isSource = r.zone.tzId == _sourceZoneId;
    final dayLabel = r.dayDifference == 0
        ? null
        : (r.dayDifference > 0
              ? '+${r.dayDifference} hari'
              : '${r.dayDifference} hari');

    return Card(
      elevation: 0,
      color: isSource ? lightGreen : Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isSource ? green : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r.zone.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isSource) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Asal', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.zone.note} • ${r.utcLabel}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatHm(r.time.hour, r.time.minute),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: green,
                  ),
                ),
                Text(
                  dayLabel != null
                      ? '${formatDateShort(r.time)} ($dayLabel)'
                      : formatDateShort(r.time),
                  style: TextStyle(
                    fontSize: 12,
                    color: dayLabel != null
                        ? Colors.deepOrange
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
