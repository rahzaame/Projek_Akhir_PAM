import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../tema/tema_app.dart';
import '../utils/format_utils.dart';

/// Admin melihat semua pemesanan jamaah dan mengubah statusnya.
class AdminBookingPage extends StatefulWidget {
  const AdminBookingPage({super.key});

  @override
  State<AdminBookingPage> createState() => _AdminBookingPageState();
}

class _AdminBookingPageState extends State<AdminBookingPage> {
  final TripService _service = TripService();

  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;
  String? _filter; // null = semua

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.fetchAllTrips();
      if (!mounted) return;
      setState(() {
        _trips = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ongoing':
        return Colors.blue.shade700;
      case 'completed':
        return AppColors.green;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade800;
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> trip) async {
    final current = trip['status']?.toString();

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Ubah status pemesanan',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final status in TripService.statuses)
              ListTile(
                leading: Icon(
                  status == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _statusColor(status),
                ),
                title: Text(TripService.statusLabel(status)),
                onTap: () => Navigator.pop(sheetContext, status),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked == current) return;

    try {
      await _service.updateStatus(trip['id'].toString(), picked);
      if (!mounted) return;
      setState(() => trip['status'] = picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status diubah menjadi ${TripService.statusLabel(picked)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null
        ? _trips
        : _trips.where((t) => t['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pemesanan'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Semua (${_trips.length})'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final status in TripService.statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(TripService.statusLabel(status)),
                      selected: _filter == status,
                      onSelected: (_) => setState(() => _filter = status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(visible)),
        ],
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Pemesanan belum bisa dimuat. Pastikan akun ini admin dan '
                'file sql/migration_integrasi.sql sudah dijalankan di Supabase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      return const Center(child: Text('Belum ada pemesanan pada filter ini.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final t = visible[index];
          final status = t['status']?.toString();
          final dep = parseDbDate(t['departure_date']);
          final total = num.tryParse(t['total_amount']?.toString() ?? '') ?? 0;

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _changeStatus(t),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t['customer_name']?.toString() ?? 'Tanpa nama',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            TripService.statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t['trip_name']?.toString() ?? '-',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dep == null ? '-' : formatDate(dep)} · '
                      '${t['participant_count'] ?? 1} peserta · '
                      '${formatMoney(total, 'IDR')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
