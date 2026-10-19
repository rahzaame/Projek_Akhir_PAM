import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../utils/format_utils.dart';

const Color _green = Color(0xFF176B50);

/// Pengaturan pengingat: jadwal, keberangkatan, dan checklist.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _service = NotificationService.instance;

  NotificationPrefs _prefs = const NotificationPrefs();
  bool _isLoading = true;
  bool _hasPermission = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.loadPrefs();
    final permission = await _service.hasPermission();
    final pending = await _service.pendingCount();

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _hasPermission = permission;
      _pending = pending;
      _isLoading = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Simpan pengaturan lalu jadwalkan ulang semua pengingat.
  Future<void> _update(NotificationPrefs next) async {
    setState(() => _prefs = next);
    await _service.savePrefs(next);
    await _service.syncAll();
    final pending = await _service.pendingCount();
    if (!mounted) return;
    setState(() => _pending = pending);
  }

  Future<void> _requestPermission() async {
    final granted = await _service.requestPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (granted) {
      await _service.syncAll();
      final pending = await _service.pendingCount();
      if (!mounted) return;
      setState(() => _pending = pending);
    } else {
      _snack('Izin notifikasi belum diberikan. Aktifkan lewat pengaturan HP.');
    }
  }

  Future<void> _pickChecklistTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _prefs.checklistHour,
        minute: _prefs.checklistMinute,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    await _update(
      _prefs.copyWith(
        checklistHour: picked.hour,
        checklistMinute: picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifikasi')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Notifikasi pengingat hanya tersedia di Android dan iOS.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi & Pengingat')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_hasPermission)
                  Card(
                    elevation: 0,
                    color: const Color(0xFFFFF4D8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                color: Colors.brown,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Notifikasi belum diizinkan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Izinkan notifikasi agar pengingat jadwal, '
                            'keberangkatan, dan checklist bisa muncul.',
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                            ),
                            onPressed: _requestPermission,
                            child: const Text('Izinkan Notifikasi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _switchCard(
                  icon: Icons.event_available_outlined,
                  title: 'Pengingat jadwal',
                  subtitle:
                      'Notifikasi sebelum kegiatan dimulai sesuai pengaturan '
                      'tiap jadwal.',
                  value: _prefs.scheduleEnabled,
                  onChanged: (v) =>
                      _update(_prefs.copyWith(scheduleEnabled: v)),
                ),
                _switchCard(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Pengingat keberangkatan',
                  subtitle:
                      'H-7, H-1, dan pagi hari keberangkatan dari pemesananmu.',
                  value: _prefs.departureEnabled,
                  onChanged: (v) =>
                      _update(_prefs.copyWith(departureEnabled: v)),
                ),
                _switchCard(
                  icon: Icons.checklist_rounded,
                  title: 'Pengingat checklist',
                  subtitle:
                      'Pengingat harian sampai checklist persiapan lengkap.',
                  value: _prefs.checklistEnabled,
                  onChanged: (v) =>
                      _update(_prefs.copyWith(checklistEnabled: v)),
                  trailing: _prefs.checklistEnabled
                      ? TextButton.icon(
                          onPressed: _pickChecklistTime,
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text(
                            '${formatHm(_prefs.checklistHour, _prefs.checklistMinute)} WIB',
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_pending pengingat sedang terjadwal',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _hasPermission
                                  ? () async {
                                      await _service.showTest();
                                    }
                                  : null,
                              icon: const Icon(Icons.notification_add_outlined),
                              label: const Text('Kirim tes'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _service.syncAll();
                                final pending = await _service.pendingCount();
                                if (!mounted) return;
                                setState(() => _pending = pending);
                                _snack('Pengingat disinkronkan ulang.');
                              },
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Sinkronkan ulang'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Catatan: pengingat dapat tertunda beberapa menit karena '
                  'penghematan baterai Android. Jika pengingat tidak muncul, '
                  'pastikan SafarMate tidak dibatasi di pengaturan baterai.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          SwitchListTile(
            activeThumbColor: _green,
            secondary: Icon(icon, color: _green),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
            value: value,
            onChanged: onChanged,
          ),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: trailing,
              ),
            ),
        ],
      ),
    );
  }
}
