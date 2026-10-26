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
  // Koordinat Ka'bah di Makkah.
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
    // Menggabungkan gravitasi dan medan magnet untuk
    // memperkirakan arah utara magnetik.
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

    const green = Color(0xFF176B50);
    const lightGreen = Color(0xFFEAF4EF);
    const background = Color(0xFFF7F8F5);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Kompas Kiblat'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          const Text(
            'Kompas Arah Kiblat',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: green,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Arahkan perangkat untuk menemukan arah menuju Ka’bah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF60756A), height: 1.4),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'ARAH KIBLAT',
                  style: TextStyle(
                    color: Color(0xFF60756A),
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  qibla == null ? '--°' : '${qibla.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    color: green,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qibla == null ? 'Menunggu lokasi' : _directionName(qibla),
                  style: const TextStyle(color: green, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: SizedBox(
              width: 310,
              height: 310,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Lingkaran kompas.
                  Container(
                    width: 292,
                    height: 292,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: green, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14233D30),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                  ),

                  // Garis penanda pada lingkaran.
                  ...List.generate(36, (index) {
                    // Hilangkan garis pada posisi U, T, S, dan B.
                    if (index % 9 == 0) {
                      return const SizedBox.shrink();
                    }

                    final isMajor = index % 3 == 0;

                    return Transform.rotate(
                      angle: index * 10 * math.pi / 180,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 14),
                          width: isMajor ? 3 : 1.5,
                          height: isMajor ? 17 : 8,
                          decoration: BoxDecoration(
                            color: isMajor ? green : const Color(0xFFB7D9C8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Arah mata angin tetap pada tempatnya.
                  const Positioned(
                    top: 22,
                    child: Text(
                      'U',
                      style: TextStyle(
                        color: green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 22,
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 22,
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 22,
                    child: Text(
                      'T',
                      style: TextStyle(
                        color: green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (qibla != null && heading != null) ...[
                    // HANYA JARUM yang berputar.
                    Transform.rotate(
                      angle: relativeAngle,
                      child: CustomPaint(
                        size: const Size(170, 210),
                        painter: _CompassNeedlePainter(),
                      ),
                    ),

                    // Titik pusat jarum tetap di tengah.
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: green, width: 3),
                      ),
                    ),

                    // LOGO KA'BAH DI LUAR Transform.rotate.
                    // Dengan demikian, logo tidak ikut berputar.
                    const Positioned(left: 65, top: 65, child: _KaabaMarker()),
                  ] else
                    const Icon(
                      Icons.explore_outlined,
                      size: 100,
                      color: Color(0xFF9AB8A8),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: lightGreen,
                child: Icon(
                  _sensorAvailable ? Icons.check_circle : Icons.info_outline,
                  color: green,
                ),
              ),
              title: Text(
                _status,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                heading == null
                    ? 'Arah perangkat belum tersedia.'
                    : 'Arah kompas ${heading.toStringAsFixed(0)}° (${_directionName(heading)})',
              ),
            ),
          ),
          if (_position != null) ...[
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: lightGreen,
                  child: Icon(Icons.location_on_outlined, color: green),
                ),
                title: const Text(
                  'Lokasi Perangkat',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? 'Mengambil lokasi...' : 'Perbarui Lokasi'),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Akurasi kompas dipengaruhi sensor perangkat dan gangguan medan magnet. Kalibrasikan perangkat dan hindari benda logam di sekitarnya.',
                    style: TextStyle(
                      color: Color(0xFF456457),
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KaabaMarker extends StatelessWidget {
  const _KaabaMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF176B50), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(painter: _KaabaPainter()),
    );
  }
}

class _KaabaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final black = Paint()..color = const Color(0xFF202522);
    final gold = Paint()..color = const Color(0xFFD9B64C);
    final white = Paint()..color = Colors.white;
    final body = Path()
      ..moveTo(w * .16, h * .27)
      ..lineTo(w * .72, h * .16)
      ..lineTo(w * .88, h * .29)
      ..lineTo(w * .88, h * .78)
      ..lineTo(w * .34, h * .90)
      ..lineTo(w * .16, h * .76)
      ..close();
    canvas.drawPath(body, black);
    final band = Path()
      ..moveTo(w * .16, h * .36)
      ..lineTo(w * .72, h * .25)
      ..lineTo(w * .88, h * .37)
      ..lineTo(w * .88, h * .45)
      ..lineTo(w * .34, h * .56)
      ..lineTo(w * .16, h * .46)
      ..close();
    canvas.drawPath(band, gold);
    canvas.drawLine(
      Offset(w * .34, h * .56),
      Offset(w * .34, h * .90),
      white..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(w * .34, h * .56),
      Offset(w * .88, h * .45),
      gold..strokeWidth = 0.8,
    );
    final door = Path()
      ..moveTo(w * .48, h * .57)
      ..lineTo(w * .63, h * .54)
      ..lineTo(w * .63, h * .80)
      ..lineTo(w * .48, h * .84)
      ..close();
    canvas.drawPath(door, gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 23, size.height / 2)
      ..lineTo(cx + 23, size.height / 2)
      ..close();
    final bottom = Path()
      ..moveTo(cx - 23, size.height / 2)
      ..lineTo(cx, size.height)
      ..lineTo(cx + 23, size.height / 2)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF176B50));
    canvas.drawPath(bottom, Paint()..color = const Color(0xFFB7D9C8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
