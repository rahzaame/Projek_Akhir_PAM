import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFEAF4EF);
const Color safarBackground = Color(0xFFF7F8F5);

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
  bool _locationReady = false;

  String _sensorStatus = 'Menunggu sensor kompas...';
  String _locationName = 'Mencari lokasi...';
  String? _locationError;

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
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _sensorAvailable = false;
          _sensorStatus = 'Sensor akselerometer tidak tersedia.';
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
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _sensorAvailable = false;
          _sensorStatus = 'Sensor kompas tidak tersedia.';
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
      _sensorStatus = 'Sensor kompas aktif';
    });
  }

  Future<void> _getLocation() async {
    setState(() {
      _loading = true;
      _locationError = null;
      _locationName = 'Mengambil lokasi perangkat...';
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
        _locationReady = true;
        _locationName = 'Lokasi berhasil ditemukan';
      });

      // Nama kota dan provinsi diambil dari koordinat GPS.
      await _getLocationName(position.latitude, position.longitude);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locationReady = false;
        _locationError = error.toString().replaceFirst('Exception: ', '');
        _locationName = 'Lokasi belum tersedia';
      });
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
            headers: {'User-Agent': 'SafarMate/1.0', 'Accept-Language': 'id'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Nama lokasi tidak tersedia.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        throw Exception('Alamat tidak ditemukan.');
      }

      final city =
          address['city'] ??
          address['town'] ??
          address['municipality'] ??
          address['city_district'] ??
          address['county'] ??
          address['village'] ??
          address['suburb'];

      final province = address['state'] ?? address['province'];

      final country = address['country'];

      final parts = <String>[];

      if (city != null && city.toString().isNotEmpty) {
        parts.add(city.toString());
      }

      if (province != null &&
          province.toString().isNotEmpty &&
          province.toString() != city.toString()) {
        parts.add(province.toString());
      }

      if (parts.isEmpty && country != null) {
        parts.add(country.toString());
      }

      if (!mounted) return;

      setState(() {
        _locationName = parts.isEmpty
            ? 'Nama wilayah tidak tersedia'
            : parts.join(', ');
      });
    } catch (error) {
      debugPrint('Gagal mendapatkan nama lokasi: $error');

      if (!mounted) return;

      setState(() {
        _locationName = 'Nama wilayah tidak tersedia';
      });
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

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(5);
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

    // Sudut jarum relatif terhadap orientasi perangkat.
    final relativeAngle = qibla != null && heading != null
        ? (qibla - heading) * math.pi / 180
        : 0.0;

    return Scaffold(
      backgroundColor: safarBackground,
      appBar: AppBar(
        title: const Text('Kompas Kiblat'),
        backgroundColor: safarGreen,
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
              color: safarGreen,
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

          // Informasi sudut kiblat.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: safarLightGreen,
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
                    color: safarGreen,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qibla == null ? 'Menunggu lokasi' : _directionName(qibla),
                  style: const TextStyle(color: safarGreen, fontSize: 15),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Kompas.
          Center(
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
                      border: Border.all(color: safarGreen, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14233D30),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                  ),

                  // Garis skala kompas.
                  ...List.generate(36, (index) {
                    final isMajor = index % 9 == 0;

                    return Transform.rotate(
                      angle: index * 10 * math.pi / 180,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 14),
                          width: isMajor ? 2.5 : 1.5,
                          height: isMajor ? 12 : 6,
                          decoration: BoxDecoration(
                            color: isMajor
                                ? safarGreen
                                : const Color(0xFFB7D9C8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Label arah ditempatkan di antara garis skala.
                  const Positioned(top: 32, child: _DirectionLabel('U')),
                  const Positioned(right: 32, child: _DirectionLabel('T')),
                  const Positioned(bottom: 32, child: _DirectionLabel('S')),
                  const Positioned(left: 32, child: _DirectionLabel('B')),

                  // Jarum berputar mengikuti arah kiblat relatif
                  // terhadap orientasi HP.
                  if (qibla != null && heading != null)
                    Transform.rotate(
                      angle: relativeAngle,
                      child: const SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(painter: _CompassNeedlePainter()),
                      ),
                    )
                  else
                    const Icon(
                      Icons.explore_outlined,
                      size: 90,
                      color: Color(0xFF9AB8A8),
                    ),

                  // Logo Ka'bah dipisahkan dari Transform.rotate
                  // sehingga tidak ikut berputar bersama jarum.
                  if (qibla != null)
                    Positioned(
                      left: 155 + 105 * math.sin(qibla * math.pi / 180) - 23,
                      top: 155 - 105 * math.cos(qibla * math.pi / 180) - 23,
                      child: const _KaabaMarker(),
                    ),

                  // Titik tengah kompas.
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: safarGreen, width: 3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Status sensor.
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: safarLightGreen,
                child: Icon(
                  _sensorAvailable ? Icons.check_circle : Icons.info_outline,
                  color: safarGreen,
                ),
              ),
              title: Text(
                _sensorStatus,
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

          // Status perhitungan arah kiblat.
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: safarLightGreen,
                child: Icon(
                  _locationReady ? Icons.check_circle : Icons.info_outline,
                  color: safarGreen,
                ),
              ),
              title: Text(
                _locationReady
                    ? 'Arah kiblat berhasil ditentukan'
                    : _loading
                    ? 'Mengambil lokasi perangkat...'
                    : 'Arah kiblat belum tersedia',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _locationReady
                    ? 'Sudut kiblat dihitung dari koordinat GPS.'
                    : _locationError ?? 'Pastikan izin lokasi telah diberikan.',
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
              isThreeLine: true,
              leading: const CircleAvatar(
                backgroundColor: safarLightGreen,
                child: Icon(Icons.location_on_outlined, color: safarGreen),
              ),
              title: const Text(
                'Lokasi Saat Ini',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _locationName,
                    style: const TextStyle(
                      color: Color(0xFF26352D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_position != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCoordinate(_position!.latitude)}, '
                      '${_formatCoordinate(_position!.longitude)}',
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _loading ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? 'Mengambil lokasi...' : 'Perbarui Lokasi'),
            style: FilledButton.styleFrom(
              backgroundColor: safarGreen,
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
              color: safarLightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: safarGreen),
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
}

class _DirectionLabel extends StatelessWidget {
  final String label;

  const _DirectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: safarGreen,
        fontSize: 17,
        fontWeight: FontWeight.bold,
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
        border: Border.all(color: safarGreen, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const CustomPaint(painter: _KaabaPainter()),
    );
  }
}

class _KaabaPainter extends CustomPainter {
  const _KaabaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final black = Paint()..color = const Color(0xFF202522);
    final gold = Paint()..color = const Color(0xFFD9B64C);
    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.8;

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

    canvas.drawLine(Offset(w * .34, h * .56), Offset(w * .34, h * .90), white);

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
  const _CompassNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ujung hijau menunjukkan arah kiblat.
    final top = Path()
      ..moveTo(cx, cy - 90)
      ..lineTo(cx - 20, cy)
      ..lineTo(cx + 20, cy)
      ..close();

    // Bagian hijau muda menjadi ujung belakang jarum.
    final bottom = Path()
      ..moveTo(cx - 20, cy)
      ..lineTo(cx, cy + 90)
      ..lineTo(cx + 20, cy)
      ..close();

    canvas.drawPath(top, Paint()..color = safarGreen);

    canvas.drawPath(bottom, Paint()..color = const Color(0xFFB7D9C8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
