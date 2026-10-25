import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class KompasKiblatPage extends StatefulWidget {
  const KompasKiblatPage({super.key});

  @override
  State<KompasKiblatPage> createState() => _KompasKiblatPageState();
}

class _KompasKiblatPageState extends State<KompasKiblatPage> {
  static const double _kaabahLat = 21.4225;
  static const double _kaabahLon = 39.8262;

  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  Position? _position;
  double? _heading;
  double? _qiblaBearing;

  double _ax = 0;
  double _ay = 0;
  double _az = 0;
  double _mx = 0;
  double _my = 0;
  double _mz = 0;

  bool _loading = false;
  bool _sensorAvailable = false;
  String _status = 'Menunggu sensor kompas...';

  @override
  void initState() {
    super.initState();
    _startSensors();
    _getLocation();
  }

  void _startSensors() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        _ax = event.x;
        _ay = event.y;
        _az = event.z;
        _calculateHeading();
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _status = 'Sensor akselerometer tidak tersedia.';
          });
        }
      },
    );

    _magnetometerSubscription = magnetometerEventStream().listen(
      (event) {
        _mx = event.x;
        _my = event.y;
        _mz = event.z;
        _sensorAvailable = true;
        _calculateHeading();
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _sensorAvailable = false;
            _status = 'Sensor magnetometer tidak tersedia.';
          });
        }
      },
    );
  }

  void _calculateHeading() {
    final normA = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    final normM = math.sqrt(_mx * _mx + _my * _my + _mz * _mz);

    if (normA < 0.1 || normM < 0.1) return;

    final ax = _ax / normA;
    final ay = _ay / normA;
    final az = _az / normA;

    final mx = _mx / normM;
    final my = _my / normM;
    final mz = _mz / normM;

    final hx = my * az - mz * ay;
    final hy = mz * ax - mx * az;

    final heading = (math.atan2(hy, hx) * 180 / math.pi + 360) % 360;

    if (!mounted) return;

    setState(() {
      _heading = heading;
      _status = 'Sensor kompas aktif';
    });
  }

  Future<void> _getLocation() async {
    setState(() {
      _loading = true;
      _status = 'Mengambil lokasi perangkat...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Aktifkan layanan lokasi perangkat.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi belum diberikan.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final bearing = _calculateQiblaBearing(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _qiblaBearing = bearing;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  double _calculateQiblaBearing(double latitude, double longitude) {
    final lat1 = latitude * math.pi / 180;
    final lat2 = _kaabahLat * math.pi / 180;
    final deltaLon = (_kaabahLon - longitude) * math.pi / 180;

    final y = math.sin(deltaLon);
    final x =
        math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(deltaLon);

    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  String _directionName(double degrees) {
    const directions = [
      'Utara',
      'Timur Laut',
      'Timur',
      'Tenggara',
      'Selatan',
      'Barat Daya',
      'Barat',
      'Barat Laut',
    ];

    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qibla = _qiblaBearing;
    final heading = _heading;

    final relativeAngle = qibla != null && heading != null
        ? (qibla - heading) * math.pi / 180
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kompas Kiblat'),
        backgroundColor: const Color(0xFF176B4D),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F8F5),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Arah Kiblat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            qibla == null
                ? 'Menunggu lokasi...'
                : '${qibla.toStringAsFixed(1)}° dari utara',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF176B4D),
                        width: 3,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 18,
                    child: Text(
                      'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const Positioned(bottom: 18, child: Text('S')),
                  const Positioned(left: 18, child: Text('B')),
                  const Positioned(right: 18, child: Text('T')),
                  if (heading != null && qibla != null)
                    Transform.rotate(
                      angle: relativeAngle,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.navigation,
                            color: Color(0xFF176B4D),
                            size: 100,
                          ),
                          Text(
                            'KIBLAT',
                            style: TextStyle(
                              color: Color(0xFF176B4D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Icon(
                      Icons.explore_outlined,
                      size: 90,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(
                _sensorAvailable ? Icons.check_circle : Icons.info_outline,
                color: _sensorAvailable ? Colors.green : Colors.orange,
              ),
              title: Text(_status),
              subtitle: Text(
                heading == null
                    ? 'Arah perangkat belum tersedia.'
                    : 'Arah perangkat: ${heading.toStringAsFixed(1)}°',
              ),
            ),
          ),
          if (_position != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Lokasi perangkat'),
                subtitle: Text(
                  '${_position!.latitude.toStringAsFixed(5)}, '
                  '${_position!.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? 'Mengambil lokasi...' : 'Perbarui lokasi'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF176B4D),
              padding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Catatan: akurasi kompas dipengaruhi sensor perangkat, '
            'kalibrasi, dan gangguan medan magnet. Pastikan perangkat '
            'dikalibrasi dan arah yang ditampilkan sudah diperiksa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
