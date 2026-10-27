import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

class KompasKiblatPage extends StatefulWidget {
  const KompasKiblatPage({super.key});

  @override
  State<KompasKiblatPage> createState() => _KompasKiblatPageState();
}

class _KompasKiblatPageState extends State<KompasKiblatPage> {
  static const double _kaabahLat = 21.4225;
  static const double _kaabahLon = 39.8262;
  static const double _qiblaTolerance = 5.0;

  static const Color _green = Color(0xFF176B50);
  static const Color _lightGreen = Color(0xFFEAF4EF);
  static const Color _background = Color(0xFFF7F8F5);

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
  String _locationName = 'Mengambil nama lokasi...';

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
        if (!mounted) return;
        setState(() {
          _status = 'Sensor akselerometer tidak tersedia.';
        });
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
        if (!mounted) return;
        setState(() {
          _sensorAvailable = false;
          _status = 'Sensor magnetometer tidak tersedia.';
        });
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
    if (!mounted) return;

    setState(() {
      _loading = true;
      _status = 'Mengambil lokasi perangkat...';
      _locationName = 'Mengambil nama lokasi...';
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

      await _getLocationName(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = e.toString().replaceFirst('Exception: ', '');
          _locationName = 'Nama lokasi tidak tersedia';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _getLocationName(double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '10',
        'addressdetails': '1',
      });

      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'SafarMate/1.0',
              'Accept-Language': 'id',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil nama lokasi.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};

      final location = _firstAvailable([
        address['city'],
        address['town'],
        address['municipality'],
        address['county'],
        address['village'],
        address['suburb'],
        address['state_district'],
        address['state'],
      ]);

      if (!mounted) return;

      setState(() {
        _locationName = location ?? 'Lokasi terdeteksi melalui koordinat GPS';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _locationName = 'Nama lokasi tidak tersedia';
      });
    }
  }

  String? _firstAvailable(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
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

  double _angleDifference(double first, double second) {
    final difference = (first - second).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
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

    // Piringan kompas berputar berlawanan arah dengan heading perangkat,
    // sehingga arah yang sedang dihadap selalu berada di atas.
    final dialAngle = heading != null ? -heading * math.pi / 180 : 0.0;

    final relativeAngle = qibla != null && heading != null
        ? (qibla - heading) * math.pi / 180
        : 0.0;

    final qiblaFound =
        qibla != null &&
        heading != null &&
        _sensorAvailable &&
        _angleDifference(heading, qibla) <= _qiblaTolerance;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Kompas Kiblat'),
        backgroundColor: _green,
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
              color: _green,
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

          // Informasi arah kiblat hasil perhitungan GPS.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: _lightGreen,
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
                    color: _green,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qibla == null ? 'Menunggu lokasi' : _directionName(qibla),
                  style: const TextStyle(color: _green, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Kompas tanpa logo Ka'bah.
          Center(
            child: SizedBox(
              width: 310,
              height: 310,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Piringan kompas (lingkaran + skala + huruf) ikut berputar.
                  Transform.rotate(
                    angle: dialAngle,
                    child: SizedBox(
                      width: 310,
                      height: 310,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 292,
                            height: 292,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _green, width: 4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14233D30),
                                  blurRadius: 14,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                          ),

                          // Tanda skala kompas.
                          ...List.generate(36, (index) {
                            final isMajor = index % 9 == 0;

                            return Transform.rotate(
                              angle: index * 10 * math.pi / 180,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 14),
                                  width: isMajor ? 3 : 1.5,
                                  height: isMajor ? 17 : 8,
                                  decoration: BoxDecoration(
                                    color: isMajor
                                        ? _green
                                        : const Color(0xFFB7D9C8),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Huruf arah diberi latar putih agar
                          // tidak bertumpuk dengan tanda skala.
                          // Diputar balik agar huruf tetap tegak terbaca.
                          Positioned(
                            top: 17,
                            child: Transform.rotate(
                              angle: -dialAngle,
                              child: _directionLabel('U', 20),
                            ),
                          ),
                          Positioned(
                            bottom: 17,
                            child: Transform.rotate(
                              angle: -dialAngle,
                              child: _directionLabel('S', 18),
                            ),
                          ),
                          Positioned(
                            left: 17,
                            child: Transform.rotate(
                              angle: -dialAngle,
                              child: _directionLabel('B', 18),
                            ),
                          ),
                          Positioned(
                            right: 17,
                            child: Transform.rotate(
                              angle: -dialAngle,
                              child: _directionLabel('T', 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (qibla != null)
                    Transform.rotate(
                      angle: heading != null ? relativeAngle : 0.0,
                      child: const SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Jarum tetap menjadi penunjuk arah.
                            CustomPaint(
                              size: Size(170, 210),
                              painter: _CompassNeedlePainter(),
                            ),
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(color: _green, width: 3),
                                  ),
                                ),
                                child: SizedBox(width: 18, height: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
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

          // Notifikasi muncul hanya ketika arah sudah mendekati
          // hasil perhitungan kiblat dalam toleransi ±5 derajat.
          qiblaFound
              ? Container(
                  key: const ValueKey('qibla-found'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F2E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8BC5A8)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: _green, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arah Kiblat Ditemukan!',
                              style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Perangkat sudah mengarah mendekati '
                              'arah kiblat. Pertahankan posisi ini.',
                              style: TextStyle(
                                color: Color(0xFF456457),
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('qibla-not-found'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E8E3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.screen_rotation_alt_rounded,
                        color: _green,
                        size: 25,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          heading == null || qibla == null
                              ? 'Menunggu data lokasi dan sensor kompas...'
                              : 'Belum tepat. Putar perangkat perlahan '
                                    'sampai jarum menunjukkan arah kiblat.',
                          style: const TextStyle(
                            color: Color(0xFF456457),
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

          const SizedBox(height: 12),

          // Status sensor.
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _lightGreen,
                child: Icon(
                  _sensorAvailable ? Icons.check_circle : Icons.info_outline,
                  color: _green,
                ),
              ),
              title: Text(
                _status,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                heading == null
                    ? 'Arah perangkat belum tersedia.'
                    : 'Arah kompas ${heading.toStringAsFixed(0)}° '
                          '(${_directionName(heading)})',
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Nama lokasi dan koordinat GPS.
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: _lightGreen,
                child: Icon(Icons.location_on_outlined, color: _green),
              ),
              title: const Text(
                'Lokasi Perangkat',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _position == null
                    ? _locationName
                    : '$_locationName\n'
                          '${_position!.latitude.toStringAsFixed(5)}, '
                          '${_position!.longitude.toStringAsFixed(5)}',
              ),
              isThreeLine: _position != null,
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _loading ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? 'Mengambil lokasi...' : 'Perbarui Lokasi'),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
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
              color: _lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: _green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Akurasi kompas dipengaruhi sensor perangkat '
                    'dan gangguan medan magnet. Kalibrasikan perangkat '
                    'dan hindari benda logam di sekitarnya.',
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

  Widget _directionLabel(String label, double fontSize) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _green,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  const _CompassNeedlePainter();

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
