import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/riwayat_blockchain_page.dart';

import '../services/notification_service.dart';
import '../services/trip_service.dart';
import '../tema/tema_app.dart';
import '../utils/format_utils.dart';

class _HeroData {
  final Map<String, dynamic>? trip;
  final int checklistDone;
  final int voucherCount;

  const _HeroData({
    required this.trip,
    required this.checklistDone,
    required this.voucherCount,
  });
}

class TripHeroCard extends StatefulWidget {
  final VoidCallback onOpenPackages;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenChecklist;
  final VoidCallback onOpenSchedule;

  const TripHeroCard({
    super.key,
    required this.onOpenPackages,
    required this.onOpenBookings,
    required this.onOpenChecklist,
    required this.onOpenSchedule,
  });

  @override
  State<TripHeroCard> createState() => _TripHeroCardState();
}

class _TripHeroCardState extends State<TripHeroCard> {
  late Future<_HeroData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HeroData> _load() async {
    final service = TripService();
    final trip = await service.fetchFeaturedTrip();

    final prefs = await SharedPreferences.getInstance();
    final done =
        (prefs.getStringList('safarmate_checklist_completed_items') ?? [])
            .length
            .clamp(0, NotificationService.checklistTotalItems)
            .toInt();

    var vouchers = 0;
    try {
      vouchers = await service.countMyVouchers();
    } catch (_) {}

    return _HeroData(trip: trip, checklistDone: done, voucherCount: vouchers);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HeroData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.greenDark,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.cloud_off_outlined,
            title: 'Perjalanan belum bisa dimuat',
            body: 'Periksa koneksi internet, lalu coba lagi.',
            actionLabel: 'Coba lagi',
            onAction: _retry,
          );
        }

        final data = snapshot.data!;
        if (data.trip == null) {
          return _messageCard(
            icon: Icons.luggage_outlined,
            title: 'Belum ada perjalanan',
            body:
                'Pilih paket Umrah untuk mulai menyusun jadwal, '
                'checklist, dan voucher perjalananmu.',
            actionLabel: 'Lihat paket Umrah',
            onAction: widget.onOpenPackages,
          );
        }

        return _heroCard(data);
      },
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: AppColors.green),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _heroCard(_HeroData data) {
    final trip = data.trip!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final departure = parseDbDate(trip['departure_date']);
    final back = parseDbDate(trip['return_date']);
    final status = trip['status']?.toString();
    final people = trip['participant_count']?.toString() ?? '1';

    String bigNumber;
    String bigLabel;

    if (status == 'completed') {
      bigNumber = '✓';
      bigLabel = 'perjalanan selesai';
    } else if (status == 'ongoing' && departure != null) {
      final day = today.difference(departure).inDays + 1;
      bigNumber = '${day < 1 ? 1 : day}';
      final tripDays = back == null
          ? null
          : back.difference(departure).inDays + 1;
      bigLabel = tripDays == null ? 'hari berjalan' : 'dari $tripDays hari';
    } else if (departure == null) {
      bigNumber = '–';
      bigLabel = 'tanggal belum ditentukan';
    } else {
      final days = departure.difference(today).inDays;
      if (days > 0) {
        bigNumber = '$days';
        bigLabel = 'hari lagi berangkat';
      } else if (days == 0) {
        bigNumber = '0';
        bigLabel = 'berangkat hari ini';
      } else {
        bigNumber = '${-days}';
        bigLabel = 'hari sejak jadwal berangkat';
      }
    }

    final total = NotificationService.checklistTotalItems;
    final fraction = total == 0 ? 0.0 : data.checklistDone / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  trip['trip_name']?.toString() ?? 'Perjalanan Umrah',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  TripService.statusLabel(status),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            departure == null
                ? '$people peserta'
                : '${formatDate(departure)} · $people peserta',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bigNumber,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    bigLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: widget.onOpenChecklist,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checklist persiapan ${data.checklistDone}/$total',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _heroAction(
                Icons.event_note_outlined,
                'Agenda',
                widget.onOpenSchedule,
              ),
              _heroAction(
                Icons.verified_user_outlined,
                data.voucherCount > 0
                    ? 'Voucher (${data.voucherCount})'
                    : 'Voucher & detail',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiwayatBlockchainPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}
