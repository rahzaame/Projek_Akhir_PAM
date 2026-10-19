import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import '../services/timezone_service.dart';
import '../utils/format_utils.dart';
import 'notification_setting.dart';
import 'time_converter.dart';

const Color _green = Color(0xFF176B50);
const Color _lightGreen = Color(0xFFE1F2E8);

const Map<int, String> _reminderOptions = {
  -1: 'Tanpa pengingat',
  0: 'Saat kegiatan dimulai',
  10: '10 menit sebelumnya',
  30: '30 menit sebelumnya',
  60: '1 jam sebelumnya',
  120: '2 jam sebelumnya',
  1440: '1 hari sebelumnya',
};

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  final ScheduleService _service = ScheduleService();

  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String? _error;
  bool _onlyUpcoming = true;

  @override
  void initState() {
    super.initState();
    TimezoneService.ensureInitialized();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = data;
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

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<_ScheduleFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;

    try {
      final Map<String, dynamic> saved;
      if (existing == null) {
        saved = await _service.addSchedule(
          title: result.title,
          date: result.date,
          timezone: result.timezone,
          hour: result.hour,
          minute: result.minute,
          description: result.description,
          location: result.location,
          reminderMinutes: result.reminderMinutes,
        );
      } else {
        saved = await _service.updateSchedule(
          id: existing['id'].toString(),
          title: result.title,
          date: result.date,
          timezone: result.timezone,
          hour: result.hour,
          minute: result.minute,
          description: result.description,
          location: result.location,
          reminderMinutes: result.reminderMinutes,
        );
      }

      await NotificationService.instance.scheduleReminderFor(saved);
      if (!mounted) return;
      _snack(existing == null ? 'Jadwal ditambahkan.' : 'Jadwal diperbarui.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal menyimpan jadwal: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text('“${schedule['title']}” akan dihapus.'),
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
    if (confirmed != true || !mounted) return;

    try {
      final id = schedule['id'].toString();
      await _service.deleteSchedule(id);
      await NotificationService.instance.cancelReminderFor(id);
      if (!mounted) return;
      _snack('Jadwal dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal menghapus jadwal: $e');
    }
  }

  Future<void> _openImport() async {
    final choice = await showModalBottomSheet<_ImportChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ImportSheet(service: _service),
    );
    if (choice == null || !mounted) return;

    try {
      final inserted = await _service.importItinerary(
        trip: choice.trip,
        timezone: choice.timezone,
      );

      for (final row in inserted) {
        await NotificationService.instance.scheduleReminderFor(row);
      }

      if (!mounted) return;
      _snack(
        inserted.isEmpty
            ? 'Semua kegiatan itinerary sudah ada di jadwalmu.'
            : '${inserted.length} kegiatan ditambahkan ke jadwal.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (!_onlyUpcoming) return _schedules;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _schedules.where((s) {
      final d = parseDbDate(s['schedule_date']);
      return d != null && !d.isBefore(today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Saya'),
        actions: [
          IconButton(
            tooltip: 'Impor dari itinerary paket',
            onPressed: _openImport,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: 'Pengingat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _message(
        Icons.cloud_off_outlined,
        'Jadwal gagal dimuat',
        'Pastikan tabel schedules sudah dibuat di Supabase dan koneksi '
            'internet aktif.\n\n$_error',
        retry: true,
      );
    }

    final visible = _visible;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Mendatang'),
                selected: _onlyUpcoming,
                onSelected: (_) => setState(() => _onlyUpcoming = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Semua'),
                selected: !_onlyUpcoming,
                onSelected: (_) => setState(() => _onlyUpcoming = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: _message(
                Icons.event_busy_outlined,
                _onlyUpcoming
                    ? 'Belum ada jadwal mendatang'
                    : 'Belum ada jadwal',
                'Tekan Tambah untuk membuat jadwal, atau impor kegiatan dari '
                'itinerary paket yang sudah kamu pesan.',
              ),
            )
          else
            ..._buildGroups(visible),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(List<Map<String, dynamic>> items) {
    final widgets = <Widget>[];
    String? lastDate;

    for (final s in items) {
      final dateStr = s['schedule_date'].toString();
      if (dateStr != lastDate) {
        lastDate = dateStr;
        final d = parseDbDate(dateStr);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
            child: Text(
              d != null ? formatDateLong(d) : dateStr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _green,
                fontSize: 15,
              ),
            ),
          ),
        );
      }
      widgets.add(_scheduleCard(s));
    }
    return widgets;
  }

  Widget _scheduleCard(Map<String, dynamic> s) {
    final time = parseDbTime(s['start_time']);
    final date = parseDbDate(s['schedule_date']);
    final zone = TimezoneService.zoneById(
      s['timezone']?.toString() ?? 'Asia/Jakarta',
    );
    final location = s['location']?.toString() ?? '';
    final description = s['description']?.toString() ?? '';
    final reminder = (s['reminder_minutes'] as num?)?.toInt();
    final fromItinerary = s['source'] == 'itinerary';

    String? wibLabel;
    if (time != null && date != null && zone.code != 'WIB') {
      final source = TimezoneService.wallTime(
        zone.tzId,
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final wib = TimezoneService.convert(source, 'Asia/Jakarta');
      wibLabel = '≈ ${formatHm(wib.hour, wib.minute)} WIB';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    time != null ? formatHm(time.hour, time.minute) : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: _green,
                    ),
                  ),
                  Text(
                    time != null ? zone.code : 'Seharian',
                    style: const TextStyle(fontSize: 10, color: _green),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['title']?.toString() ?? 'Kegiatan',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (wibLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        wibLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  if (location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        description,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (reminder != null && time != null)
                        _tag(
                          Icons.notifications_active_outlined,
                          reminder == 0
                              ? 'Saat mulai'
                              : (_reminderOptions[reminder] ??
                                    '$reminder menit'),
                        ),
                      if (fromItinerary)
                        _tag(Icons.route_outlined, 'Dari itinerary'),
                      if (time != null && date != null)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.public, size: 14),
                          label: const Text(
                            'Bandingkan waktu',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TimeConverterPage(
                                initialDate: date,
                                initialTime: TimeOfDay(
                                  hour: time.hour,
                                  minute: time.minute,
                                ),
                                initialZoneId: zone.tzId,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _openForm(existing: s);
                if (value == 'delete') _delete(s);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black54),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String description, {
    bool retry = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _green),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
            if (retry) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleFormResult {
  final String title;
  final DateTime date;
  final int? hour;
  final int? minute;
  final String timezone;
  final String location;
  final String description;
  final int? reminderMinutes;

  const _ScheduleFormResult({
    required this.title,
    required this.date,
    required this.hour,
    required this.minute,
    required this.timezone,
    required this.location,
    required this.description,
    required this.reminderMinutes,
  });
}

class _ScheduleFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _ScheduleFormSheet({this.existing});

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;

  late DateTime _date;
  TimeOfDay? _time;
  late String _timezone;
  late int _reminder; // -1 = tanpa pengingat

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _title = TextEditingController(text: e?['title']?.toString() ?? '');
    _location = TextEditingController(text: e?['location']?.toString() ?? '');
    _description = TextEditingController(
      text: e?['description']?.toString() ?? '',
    );

    if (e == null) {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _time = const TimeOfDay(hour: 9, minute: 0);
      _timezone = 'Asia/Jakarta';
      _reminder = 30;
    } else {
      _date = parseDbDate(e['schedule_date']) ?? DateTime.now();
      final t = parseDbTime(e['start_time']);
      _time = t != null ? TimeOfDay(hour: t.hour, minute: t.minute) : null;
      _timezone = e['timezone']?.toString() ?? 'Asia/Jakarta';
      _reminder = (e['reminder_minutes'] as num?)?.toInt() ?? -1;
      if (!_reminderOptions.containsKey(_reminder)) _reminder = -1;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      _ScheduleFormResult(
        title: _title.text.trim(),
        date: _date,
        hour: _time?.hour,
        minute: _time?.minute,
        timezone: _timezone,
        location: _location.text.trim(),
        description: _description.text.trim(),
        // Pengingat hanya bermakna bila jadwal punya jam.
        reminderMinutes: (_time == null || _reminder < 0) ? null : _reminder,
      ),
    );
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
                editing ? 'Ubah Jadwal' : 'Tambah Jadwal',
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
                  labelText: 'Nama kegiatan',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama kegiatan wajib diisi'
                    : null,
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
                      label: Text(
                        _time != null
                            ? formatHm(_time!.hour, _time!.minute)
                            : 'Tanpa jam',
                      ),
                    ),
                  ),
                ],
              ),
              if (_time != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _time = null),
                    child: const Text('Hapus jam (kegiatan seharian)'),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Zona waktu kegiatan',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final z in TimezoneService.zones)
                    DropdownMenuItem(
                      value: z.tzId,
                      child: Text('${z.code} • ${z.note}'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _timezone = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Lokasi (opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _reminder,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Pengingat',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notifications_active_outlined),
                  helperText: _time == null
                      ? 'Pengingat butuh jam kegiatan'
                      : null,
                ),
                items: [
                  for (final entry in _reminderOptions.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _time == null
                    ? null
                    : (v) {
                        if (v != null) setState(() => _reminder = v);
                      },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submit,
                  child: Text(editing ? 'Simpan Perubahan' : 'Simpan Jadwal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportChoice {
  final Map<String, dynamic> trip;
  final String timezone;

  const _ImportChoice(this.trip, this.timezone);
}

class _ImportSheet extends StatefulWidget {
  final ScheduleService service;

  const _ImportSheet({required this.service});

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  late final Future<List<Map<String, dynamic>>> _tripsFuture;
  Map<String, dynamic>? _selected;
  String _timezone = 'Asia/Riyadh';

  @override
  void initState() {
    super.initState();
    _tripsFuture = widget.service.fetchTrips();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'Gagal memuat pemesanan: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final trips = (snapshot.data ?? [])
                .where((t) => t['package_id'] != null)
                .toList();

            if (trips.isEmpty) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    'Belum ada pemesanan paket.\nPesan paket Umrah terlebih '
                    'dahulu untuk mengimpor itinerary-nya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Impor Itinerary ke Jadwal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kegiatan paket akan disalin ke jadwalmu berdasarkan '
                  'tanggal keberangkatan (Hari 1 = tanggal berangkat).',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final trip in trips)
                        RadioListTile<Map<String, dynamic>>(
                          value: trip,
                          groupValue: _selected,
                          activeColor: _green,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            trip['trip_name']?.toString() ?? 'Perjalanan',
                          ),
                          subtitle: Text(
                            'Berangkat ${_dateLabel(trip['departure_date'])}',
                          ),
                          onChanged: (v) => setState(() => _selected = v),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Jam itinerary memakai zona waktu',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final z in TimezoneService.zones)
                      DropdownMenuItem(
                        value: z.tzId,
                        child: Text('${z.code} • ${z.note}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _timezone = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.pop(
                            context,
                            _ImportChoice(_selected!, _timezone),
                          ),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Impor ke Jadwal'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _dateLabel(dynamic value) {
    final d = parseDbDate(value);
    return d != null ? formatDate(d) : '-';
  }
}
