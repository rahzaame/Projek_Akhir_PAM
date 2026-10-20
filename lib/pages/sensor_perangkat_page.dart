import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorPerangkatPage extends StatefulWidget {
  const SensorPerangkatPage({super.key});

  @override
  State<SensorPerangkatPage> createState() => _SensorPerangkatPageState();
}

class _SensorPerangkatPageState extends State<SensorPerangkatPage> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  double _ax = 0;
  double _ay = 0;
  double _az = 0;

  double _mx = 0;
  double _my = 0;
  double _mz = 0;

  bool _accelerometerAktif = false;
  bool _magnetometerAktif = false;

  String _statusAccelerometer = 'Menunggu data sensor...';
  String _statusMagnetometer = 'Menunggu data sensor...';

  @override
  void initState() {
    super.initState();
    _mulaiAccelerometer();
    _mulaiMagnetometer();
  }

  void _mulaiAccelerometer() {
    _accelerometerSubscription =
        accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval)
            .listen(
              (event) {
                if (!mounted) return;

                setState(() {
                  _ax = event.x;
                  _ay = event.y;
                  _az = event.z;
                  _accelerometerAktif = true;
                  _statusAccelerometer = 'Sensor aktif';
                });
              },
              onError: (Object error) {
                if (!mounted) return;

                setState(() {
                  _accelerometerAktif = false;
                  _statusAccelerometer = 'Sensor tidak tersedia';
                });
              },
            );
  }

  void _mulaiMagnetometer() {
    _magnetometerSubscription =
        magnetometerEventStream(samplingPeriod: SensorInterval.normalInterval)
            .listen(
              (event) {
                if (!mounted) return;

                setState(() {
                  _mx = event.x;
                  _my = event.y;
                  _mz = event.z;
                  _magnetometerAktif = true;
                  _statusMagnetometer = 'Sensor aktif';
                });
              },
              onError: (Object error) {
                if (!mounted) return;

                setState(() {
                  _magnetometerAktif = false;
                  _statusMagnetometer = 'Sensor tidak tersedia';
                });
              },
            );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    super.dispose();
  }

  Widget _kartuSensor({
    required String judul,
    required String deskripsi,
    required bool aktif,
    required String status,
    required IconData ikon,
    required List<(String, double, String)> data,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 30, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judul,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        deskripsi,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  aktif ? Icons.check_circle : Icons.info_outline,
                  color: aktif ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                color: aktif ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 24),
            ...data.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Sumbu ${item.$1}')),
                    Text(
                      '${item.$2.toStringAsFixed(2)} ${item.$3}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFeatures: [],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Perangkat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pantau gerakan dan medan magnet perangkat secara langsung.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          _kartuSensor(
            judul: 'Accelerometer',
            deskripsi: 'Percepatan perangkat',
            aktif: _accelerometerAktif,
            status: _statusAccelerometer,
            ikon: Icons.screen_rotation_outlined,
            data: [('X', _ax, 'm/s²'), ('Y', _ay, 'm/s²'), ('Z', _az, 'm/s²')],
          ),

          _kartuSensor(
            judul: 'Magnetometer',
            deskripsi: 'Medan magnet perangkat',
            aktif: _magnetometerAktif,
            status: _statusMagnetometer,
            ikon: Icons.explore_outlined,
            data: [('X', _mx, 'µT'), ('Y', _my, 'µT'), ('Z', _mz, 'µT')],
          ),

          Card(
            color: Colors.orange.withValues(alpha: 0.10),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Petunjuk penggunaan sensor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Gerakkan atau miringkan perangkat untuk melihat '
                    'perubahan data accelerometer.\n\n'
                    '• Putar perangkat untuk melihat perubahan data '
                    'magnetometer jika sensor tersedia.\n\n'
                    '• Jika kompas tidak stabil, jauhkan perangkat '
                    'dari benda logam dan sumber gangguan magnetik, '
                    'lalu gerakkan perangkat perlahan membentuk angka '
                    'delapan jika diperlukan.\n\n'
                    '• Nilai sensor saja bukan penunjuk arah kiblat. '
                    'Gunakan halaman Kompas Kiblat untuk fitur tersebut.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
