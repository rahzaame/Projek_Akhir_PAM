import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/format_utils.dart';
import 'schedule_service.dart';
import 'timezone_service.dart';

class NotificationPrefs {
  final bool scheduleEnabled;
  final bool departureEnabled;
  final bool checklistEnabled;
  final int checklistHour;
  final int checklistMinute;

  const NotificationPrefs({
    this.scheduleEnabled = true,
    this.departureEnabled = true,
    this.checklistEnabled = true,
    this.checklistHour = 19,
    this.checklistMinute = 0,
  });

  NotificationPrefs copyWith({
    bool? scheduleEnabled,
    bool? departureEnabled,
    bool? checklistEnabled,
    int? checklistHour,
    int? checklistMinute,
  }) {
    return NotificationPrefs(
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
      departureEnabled: departureEnabled ?? this.departureEnabled,
      checklistEnabled: checklistEnabled ?? this.checklistEnabled,
      checklistHour: checklistHour ?? this.checklistHour,
      checklistMinute: checklistMinute ?? this.checklistMinute,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int checklistTotalItems = 20;
  static const String _checklistStorageKey =
      'safarmate_checklist_completed_items';

  static const String _reminderZone = 'Asia/Jakarta';

  static const String _prefScheduleEnabled = 'notif_schedule_enabled';
  static const String _prefDepartureEnabled = 'notif_departure_enabled';
  static const String _prefChecklistEnabled = 'notif_checklist_enabled';
  static const String _prefChecklistHour = 'notif_checklist_hour';
  static const String _prefChecklistMinute = 'notif_checklist_minute';

  static const String _payloadSchedule = 'schedule:';
  static const String _payloadDeparture = 'departure:';
  static const String _payloadChecklist = 'checklist';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isReady => _ready;

  Future<void> init() async {
    TimezoneService.ensureInitialized();
    if (!isSupported || _ready) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<bool> hasPermission() async {
    if (!_ready) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final options = await ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  Future<NotificationPrefs> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      scheduleEnabled: prefs.getBool(_prefScheduleEnabled) ?? true,
      departureEnabled: prefs.getBool(_prefDepartureEnabled) ?? true,
      checklistEnabled: prefs.getBool(_prefChecklistEnabled) ?? true,
      checklistHour: prefs.getInt(_prefChecklistHour) ?? 19,
      checklistMinute: prefs.getInt(_prefChecklistMinute) ?? 0,
    );
  }

  Future<void> savePrefs(NotificationPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefScheduleEnabled, value.scheduleEnabled);
    await prefs.setBool(_prefDepartureEnabled, value.departureEnabled);
    await prefs.setBool(_prefChecklistEnabled, value.checklistEnabled);
    await prefs.setInt(_prefChecklistHour, value.checklistHour);
    await prefs.setInt(_prefChecklistMinute, value.checklistMinute);
  }

  Future<void> syncAll() async {
    if (!_ready) return;

    try {
      final prefs = await loadPrefs();
      final service = ScheduleService();

      await _cancelByPayload(_payloadSchedule);
      if (prefs.scheduleEnabled) {
        final schedules = await service.fetchSchedules();
        await _scheduleManyReminders(schedules);
      }

      await _cancelByPayload(_payloadDeparture);
      if (prefs.departureEnabled) {
        final trips = await service.fetchTrips();
        for (final trip in trips) {
          await _scheduleDepartureReminders(trip);
        }
      }

      await _cancelByPayload(_payloadChecklist);
      if (prefs.checklistEnabled) {
        await _scheduleChecklistReminder(prefs);
      }
    } catch (e) {
      debugPrint('NotificationService.syncAll gagal: $e');
    }
  }

  Future<int> pendingCount() async {
    if (!_ready) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: _stableId('test'),
      title: 'SafarMate',
      body: 'Notifikasi berjalan dengan baik. Semoga perjalananmu lancar!',
      notificationDetails: _details(_Channel.schedule),
    );
  }

  Future<void> scheduleReminderFor(Map<String, dynamic> schedule) async {
    if (!_ready) return;
    try {
      final prefs = await loadPrefs();
      await cancelReminderFor(schedule['id'].toString());
      if (!prefs.scheduleEnabled) return;
      await _scheduleOneReminder(schedule);
    } catch (e) {
      debugPrint('Gagal menjadwalkan pengingat: $e');
    }
  }

  Future<void> cancelReminderFor(String scheduleId) async {
    if (!_ready) return;
    await _plugin.cancel(id: _stableId('$_payloadSchedule$scheduleId'));
  }

  Future<void> _scheduleManyReminders(
    List<Map<String, dynamic>> schedules,
  ) async {
    final now = DateTime.now();
    final upcoming = <MapEntry<DateTime, Map<String, dynamic>>>[];

    for (final s in schedules) {
      final trigger = reminderTime(s);
      if (trigger != null && trigger.isAfter(now)) {
        upcoming.add(MapEntry(trigger, s));
      }
    }

    upcoming.sort((a, b) => a.key.compareTo(b.key));

    for (final entry in upcoming.take(50)) {
      await _scheduleOneReminder(entry.value);
    }
  }

  Future<void> _scheduleOneReminder(Map<String, dynamic> schedule) async {
    final trigger = reminderTime(schedule);
    if (trigger == null || !trigger.isAfter(DateTime.now())) return;

    final id = schedule['id'].toString();
    final minutes = (schedule['reminder_minutes'] as num).toInt();
    final title = schedule['title']?.toString() ?? 'Kegiatan';
    final location = schedule['location']?.toString();
    final zone = TimezoneService.zoneById(
      schedule['timezone']?.toString() ?? _reminderZone,
    );
    final time = parseDbTime(schedule['start_time'])!;

    final when = minutes == 0
        ? 'Dimulai sekarang'
        : 'Dimulai ${_reminderLabel(minutes)} lagi';

    await _zoned(
      id: _stableId('$_payloadSchedule$id'),
      when: trigger,
      title: title,
      body:
          '$when • ${formatHm(time.hour, time.minute)} ${zone.code}'
          '${location != null ? ' • $location' : ''}',
      payload: '$_payloadSchedule$id',
      details: _details(_Channel.schedule),
    );
  }

  static DateTime? reminderTime(Map<String, dynamic> schedule) {
    final minutes = (schedule['reminder_minutes'] as num?)?.toInt();
    final date = parseDbDate(schedule['schedule_date']);
    final time = parseDbTime(schedule['start_time']);
    if (minutes == null || date == null || time == null) return null;

    final start = TimezoneService.wallTime(
      schedule['timezone']?.toString() ?? _reminderZone,
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return start.subtract(Duration(minutes: minutes));
  }

  static String _reminderLabel(int minutes) {
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} hari';
    if (minutes % 60 == 0) return '${minutes ~/ 60} jam';
    return '$minutes menit';
  }

  Future<void> _scheduleDepartureReminders(Map<String, dynamic> trip) async {
    final departure = parseDbDate(trip['departure_date']);
    if (departure == null) return;

    final tripId = trip['id'].toString();
    final name = trip['trip_name']?.toString() ?? 'Perjalanan Umrah';
    final dateLabel = formatDateLong(departure);

    final reminders = <({int daysBefore, int hour, String title, String body})>[
      (
        daysBefore: 7,
        hour: 8,
        title: 'Keberangkatan 7 hari lagi',
        body: '$name berangkat $dateLabel. Cek paspor, visa, dan checklist!',
      ),
      (
        daysBefore: 1,
        hour: 8,
        title: 'Besok keberangkatanmu',
        body: '$name berangkat besok. Pastikan koper dan dokumen sudah siap.',
      ),
      (
        daysBefore: 0,
        hour: 5,
        title: 'Hari keberangkatan',
        body:
            'Bismillah, $name berangkat hari ini. Semoga perjalananmu lancar.',
      ),
    ];

    for (final r in reminders) {
      final day = departure.subtract(Duration(days: r.daysBefore));
      final when = TimezoneService.wallTime(
        _reminderZone,
        day.year,
        day.month,
        day.day,
        r.hour,
        0,
      );
      if (!when.isAfter(tz.TZDateTime.now(tz.UTC))) continue;

      final key = '$_payloadDeparture$tripId:${r.daysBefore}';
      await _zoned(
        id: _stableId(key),
        when: when,
        title: r.title,
        body: r.body,
        payload: key,
        details: _details(_Channel.departure),
      );
    }
  }

  Future<void> _scheduleChecklistReminder(NotificationPrefs prefs) async {
    final shared = await SharedPreferences.getInstance();
    final done =
        (shared.getStringList(_checklistStorageKey) ?? const <String>[]).length;
    if (done >= checklistTotalItems) return;

    final location = TimezoneService.location(_reminderZone);
    final now = tz.TZDateTime.now(location);
    var first = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      prefs.checklistHour,
      prefs.checklistMinute,
    );
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _stableId(_payloadChecklist),
      scheduledDate: first,
      notificationDetails: _details(_Channel.checklist),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Checklist persiapan Umrah',
      body:
          'Baru $done dari $checklistTotalItems persiapan selesai. '
          'Yuk lengkapi hari ini!',
      payload: _payloadChecklist,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _zoned({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
    required NotificationDetails details,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> _cancelByPayload(String prefix) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(prefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  NotificationDetails _details(_Channel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  static int _stableId(String key) {
    int hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}

class _Channel {
  final String id;
  final String name;
  final String description;

  const _Channel(this.id, this.name, this.description);

  static const schedule = _Channel(
    'safarmate_schedule',
    'Pengingat Jadwal',
    'Pengingat kegiatan dan agenda perjalanan',
  );
  static const departure = _Channel(
    'safarmate_departure',
    'Pengingat Keberangkatan',
    'Pengingat menjelang hari keberangkatan',
  );
  static const checklist = _Channel(
    'safarmate_checklist',
    'Pengingat Checklist',
    'Pengingat melengkapi checklist persiapan Umrah',
  );
}
