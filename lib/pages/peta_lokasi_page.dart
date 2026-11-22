import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

/// Moda perjalanan. Setiap moda memakai layanan rute OSM yang berbeda
/// (mobil, pejalan kaki, sepeda) agar hasil rutenya sesuai jenis jalannya.
enum _TravelMode {
  driving('Mobil', Icons.directions_car, 'routed-car', 'driving'),
  walking('Jalan kaki', Icons.directions_walk, 'routed-foot', 'walking'),
  cycling('Sepeda', Icons.directions_bike, 'routed-bike', 'bicycling');

  final String label;
  final IconData icon;
  final String osrmService;
  final String googleMode;

  const _TravelMode(this.label, this.icon, this.osrmService, this.googleMode);
}

class _RouteStep {
  final String instruction;
  final IconData icon;
  final double distanceMeters;
  final LatLng? location;

  const _RouteStep({
    required this.instruction,
    required this.icon,
    required this.distanceMeters,
    this.location,
  });
}

class PetaLokasiPage extends StatefulWidget {
  const PetaLokasiPage({super.key});

  @override
  State<PetaLokasiPage> createState() => _PetaLokasiPageState();
}

class _PetaLokasiPageState extends State<PetaLokasiPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCity = 'Makkah';
  Set<String> _savedIds = {};
  List<_Destination> _searchResults = [];
  Position? _currentPosition;
  _Destination? _selectedSearchResult;
  bool _showSavedOnly = false;
  bool _loadingLocation = false;
  bool _searching = false;
  bool _mapReady = false;

  // --- State rute ---
  bool _loadingRoute = false;
  bool _showSteps = false;
  bool _followMe = false;
  _TravelMode _travelMode = _TravelMode.driving;
  _Destination? _routeDestination;
  List<LatLng> _routePoints = [];
  List<_RouteStep> _routeSteps = [];
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  int _routeToken = 0;
  StreamSubscription<Position>? _positionSub;

  bool get _hasRoute =>
      _routePoints.length >= 2 &&
      _routeDistanceKm != null &&
      _routeDurationMinutes != null &&
      _routeDestination != null;

  static const LatLng _makkahCenter = LatLng(21.4225, 39.8262);
  static const LatLng _madinahCenter = LatLng(24.4672, 39.6111);
  static const LatLng _turkeyCenter = LatLng(41.0082, 28.9784);

  static const String _savedKey = 'safarmate_saved_destinations';
  static const String _customKey = 'safarmate_custom_destinations';
  static const String _userAgent =
      'SafarMateFlutterApp/1.0 (location search and routing feature)';

  final List<_Destination> _destinations = const [
    _Destination(
      id: 'masjidil_haram',
      name: 'Masjidil Haram',
      city: 'Makkah',
      description: "Masjid suci yang mengelilingi Ka'bah.",
      location: LatLng(21.4225, 39.8262),
    ),
    _Destination(
      id: 'jabal_nur',
      name: 'Jabal Nur',
      city: 'Makkah',
      description: 'Gunung yang dikenal dengan Gua Hira.',
      location: LatLng(21.4572, 39.8592),
    ),
    _Destination(
      id: 'arafat',
      name: 'Padang Arafah',
      city: 'Makkah',
      description: 'Salah satu tempat penting dalam pelaksanaan haji.',
      location: LatLng(21.3549, 39.9841),
    ),
    _Destination(
      id: 'masjid_nabawi',
      name: 'Masjid Nabawi',
      city: 'Madinah',
      description: 'Masjid Nabawi berada di Kota Madinah.',
      location: LatLng(24.4672, 39.6111),
    ),
    _Destination(
      id: 'masjid_quba',
      name: 'Masjid Quba',
      city: 'Madinah',
      description: 'Masjid bersejarah di Kota Madinah.',
      location: LatLng(24.4398, 39.6178),
    ),
    _Destination(
      id: 'masjid_qiblatain',
      name: 'Masjid Qiblatain',
      city: 'Madinah',
      description: 'Masjid bersejarah yang dikenal sebagai Masjid Dua Kiblat.',
      location: LatLng(24.4843, 39.5788),
    ),
    _Destination(
      id: 'hagia_sophia',
      name: 'Hagia Sophia',
      city: 'Turki',
      description: 'Bangunan bersejarah di Istanbul, Turki.',
      location: LatLng(41.0086, 28.9802),
    ),
    _Destination(
      id: 'blue_mosque',
      name: 'Masjid Sultan Ahmed',
      city: 'Turki',
      description: 'Masjid bersejarah yang dikenal sebagai Blue Mosque.',
      location: LatLng(41.0054, 28.9768),
    ),
  ];

  List<_Destination> _customDestinations = [];

  @override
  void initState() {
    super.initState();
    _loadSavedDestinations();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Penyimpanan lokasi
  // ---------------------------------------------------------------------------

  Future<void> _loadSavedDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getStringList(_customKey) ?? [];
    final loadedCustom = <_Destination>[];

    for (final item in customJson) {
      try {
        loadedCustom.add(
          _Destination.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {
        // Lewati data tersimpan yang formatnya tidak valid.
      }
    }

    if (!mounted) return;
    setState(() {
      _savedIds = (prefs.getStringList(_savedKey) ?? []).toSet();
      _customDestinations = loadedCustom;
    });
  }

  Future<void> _persistCustomDestinations(List<_Destination> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _customKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _toggleSaved(_Destination destination) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Set<String>.from(_savedIds);

    if (updated.contains(destination.id)) {
      updated.remove(destination.id);
    } else {
      updated.add(destination.id);
    }

    await prefs.setStringList(_savedKey, updated.toList());
    if (!mounted) return;

    setState(() => _savedIds = updated);
  }

  Future<void> _saveSearchResult(_Destination destination) async {
    final existingIndex = _customDestinations.indexWhere(
      (item) => item.id == destination.id,
    );
    final updated = List<_Destination>.from(_customDestinations);

    if (existingIndex >= 0) {
      updated[existingIndex] = destination;
    } else {
      updated.add(destination);
    }

    await _persistCustomDestinations(updated);
    if (!mounted) return;

    setState(() => _customDestinations = updated);
    await _toggleSaved(destination);
  }

  /// Simpan / hapus simpanan untuk destinasi bawaan maupun hasil pencarian.
  Future<void> _toggleSavedAny(_Destination destination) async {
    final isSaved = _savedIds.contains(destination.id);
    final isSearchResult = destination.id.startsWith('search_');

    if (isSearchResult && !isSaved) {
      await _saveSearchResult(destination);
    } else {
      await _toggleSaved(destination);
    }
  }

  // ---------------------------------------------------------------------------
  // Pencarian tempat
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> _requestNominatim(
    String query,
    String countryCode,
  ) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '10',
      'addressdetails': '1',
      'accept-language': 'id,en',
      'countrycodes': countryCode,
      'dedupe': '1',
    });

    final response = await http
        .get(uri, headers: const {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Layanan pencarian memberi status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded;
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showMessage('Masukkan nama lokasi yang ingin dicari.');
      return;
    }
    if (_searching) return;

    setState(() {
      _searching = true;
      _searchResults = [];
      _selectedSearchResult = null;
    });

    final isTurkey = _selectedCity == 'Turki';
    final country = isTurkey ? 'Turkey' : 'Saudi Arabia';
    final countryCode = isTurkey ? 'tr' : 'sa';
    final city = isTurkey
        ? 'Istanbul'
        : (_selectedCity == 'Makkah' ? 'Mecca' : 'Medina');

    try {
      // Percobaan pertama: nama lokasi + kota + negara.
      var data = await _requestNominatim(
        '$query, $city, $country',
        countryCode,
      );

      // Jika belum ditemukan, longgarkan pencarian dengan menghapus nama kota.
      if (data.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 1100));
        data = await _requestNominatim('$query, $country', countryCode);
      }

      final results = <_Destination>[];
      final seenIds = <String>{};

      for (final rawItem in data) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = item['display_name']?.toString();

        if (lat == null || lon == null || displayName == null) continue;

        final rawName = item['name']?.toString().trim() ?? '';
        final name = rawName.isNotEmpty
            ? rawName
            : displayName.split(',').first.trim();

        final osmId = item['osm_id'] ?? item['place_id'];
        final osmType = item['osm_type'] ?? 'place';
        final id = 'search_${osmType}_$osmId';

        if (!seenIds.add(id)) continue;

        results.add(
          _Destination(
            id: id,
            name: name,
            city: _selectedCity,
            description: displayName,
            location: LatLng(lat, lon),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _searchResults = results);

      if (results.isEmpty) {
        _showMessage(
          'Lokasi belum ditemukan. Coba gunakan nama tempat yang lebih umum atau tambahkan nama kota.',
        );
      }
    } catch (e) {
      debugPrint('Pencarian lokasi gagal: $e');
      _showMessage('Pencarian gagal. Periksa koneksi internet lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(_Destination destination) {
    _resetRoute();
    setState(() {
      _selectedSearchResult = destination;
      _showSavedOnly = false;
    });
    if (_mapReady) _mapController.move(destination.location, 16);
  }

  // ---------------------------------------------------------------------------
  // Lokasi pengguna
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  LatLng get _selectedCenter {
    switch (_selectedCity) {
      case 'Madinah':
        return _madinahCenter;
      case 'Turki':
        return _turkeyCenter;
      default:
        return _makkahCenter;
    }
  }

  void _focusCity() {
    if (_mapReady) _mapController.move(_selectedCenter, 12);
  }

  Future<Position?> _getUserPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Aktifkan layanan lokasi/GPS perangkat terlebih dahulu.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showMessage('Izin lokasi belum diberikan.');
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.',
      );
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      // GPS lambat (mis. di dalam gedung): pakai lokasi terakhir bila ada.
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) rethrow;
      return last;
    }
  }

  Future<void> _showCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      final position = await _getUserPosition();
      if (position == null || !mounted) return;
      setState(() => _currentPosition = position);

      if (_mapReady) {
        _mapController.move(LatLng(position.latitude, position.longitude), 15);
      }
    } catch (e) {
      _showMessage('Lokasi belum berhasil diperoleh. Coba lagi.');
      debugPrint('Gagal mendapatkan lokasi: $e');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  /// Memperbarui posisi pengguna secara langsung selama rute aktif.
  void _startTracking() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() => _currentPosition = position);
          if (_followMe && _mapReady) {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
            );
          }
        }, onError: (Object e) => debugPrint('Pelacakan lokasi gagal: $e'));
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  // ---------------------------------------------------------------------------
  // Rute
  // ---------------------------------------------------------------------------

  void _resetRoute() {
    _routeToken++;
    _stopTracking();
    setState(() {
      _routeDestination = null;
      _routePoints = [];
      _routeSteps = [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _showSteps = false;
      _followMe = false;
      _loadingRoute = false;
    });
  }

  Future<void> _showRoute(
    _Destination destination, {
    _TravelMode? mode,
    bool reuseLocation = false,
  }) async {
    if (_loadingRoute) return;
    final travelMode = mode ?? _travelMode;
    final token = ++_routeToken;

    setState(() => _loadingRoute = true);

    try {
      final position = (reuseLocation && _currentPosition != null)
          ? _currentPosition
          : await _getUserPosition();
      if (position == null || !mounted || token != _routeToken) return;

      final origin = LatLng(position.latitude, position.longitude);
      final target = destination.location;

      final coordinates =
          '${origin.longitude},${origin.latitude};${target.longitude},${target.latitude}';
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/${travelMode.osrmService}/route/v1/driving/$coordinates'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Layanan rute memberi status ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>? ?? [];
      if (body['code'] != 'Ok' || routes.isEmpty) {
        _showMessage(
          'Rute ${travelMode.label.toLowerCase()} ke lokasi ini belum tersedia.',
        );
        return;
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinatesList = geometry['coordinates'] as List<dynamic>;
      final points = coordinatesList.map((coordinate) {
        final pair = coordinate as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      final steps = <_RouteStep>[];
      for (final leg in (route['legs'] as List<dynamic>? ?? [])) {
        for (final rawStep in ((leg as Map)['steps'] as List<dynamic>? ?? [])) {
          steps.add(_stepFromJson(Map<String, dynamic>.from(rawStep as Map)));
        }
      }

      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSeconds = (route['duration'] as num).toDouble();

      if (!mounted || token != _routeToken) return;
      setState(() {
        _currentPosition = position;
        _travelMode = travelMode;
        _routeDestination = destination;
        _routePoints = points;
        _routeSteps = steps;
        _routeDistanceKm = distanceMeters / 1000;
        _routeDurationMinutes = durationSeconds / 60;
        _showSteps = false;
      });

      _startTracking();

      if (_mapReady && points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(50, 80, 50, 270),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal memuat rute: $e');
      if (token == _routeToken) {
        _showMessage(
          'Rute belum berhasil dimuat. Periksa koneksi internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted && token == _routeToken) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  void _changeTravelMode(_TravelMode mode) {
    final destination = _routeDestination;
    if (destination == null || mode == _travelMode) return;
    _showRoute(destination, mode: mode, reuseLocation: true);
  }

  // --- Terjemahan langkah belokan OSRM ke bahasa Indonesia ---

  String _modifierLabel(String modifier) {
    switch (modifier) {
      case 'left':
        return 'kiri';
      case 'right':
        return 'kanan';
      case 'slight left':
        return 'serong kiri';
      case 'slight right':
        return 'serong kanan';
      case 'sharp left':
        return 'tajam ke kiri';
      case 'sharp right':
        return 'tajam ke kanan';
      case 'straight':
        return 'lurus';
      default:
        return '';
    }
  }

  IconData _iconFor(String type, String modifier) {
    if (type == 'depart') return Icons.navigation;
    if (type == 'arrive') return Icons.flag;
    if (type == 'roundabout' || type == 'rotary' || type == 'roundabout turn') {
      return Icons.roundabout_left;
    }
    switch (modifier) {
      case 'left':
      case 'sharp left':
        return Icons.turn_left;
      case 'right':
      case 'sharp right':
        return Icons.turn_right;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'slight right':
        return Icons.turn_slight_right;
      case 'uturn':
        return Icons.u_turn_left;
      default:
        return Icons.straight;
    }
  }

  _RouteStep _stepFromJson(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] is Map
        ? Map<String, dynamic>.from(step['maneuver'] as Map)
        : <String, dynamic>{};
    final type = maneuver['type']?.toString() ?? '';
    final modifier = maneuver['modifier']?.toString() ?? '';
    final name = (step['name']?.toString() ?? '').trim();
    final dir = _modifierLabel(modifier);
    final onRoad = name.isEmpty ? '' : ' ke $name';

    String text;
    switch (type) {
      case 'depart':
        text = name.isEmpty ? 'Mulai perjalanan' : 'Mulai perjalanan di $name';
        break;
      case 'arrive':
        text = (modifier == 'left' || modifier == 'right')
            ? 'Anda tiba di tujuan (di sisi $dir)'
            : 'Anda tiba di tujuan';
        break;
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        final exit = maneuver['exit'];
        text = exit != null
            ? 'Masuk bundaran, ambil jalan keluar ke-$exit$onRoad'
            : 'Masuk bundaran$onRoad';
        break;
      case 'fork':
        text = dir.isEmpty
            ? 'Ambil percabangan$onRoad'
            : 'Ambil percabangan $dir$onRoad';
        break;
      case 'merge':
        text = 'Gabung ke jalur$onRoad'.replaceFirst('jalur ke', 'jalur');
        break;
      case 'continue':
      case 'new name':
        text = name.isEmpty ? 'Lanjutkan lurus' : 'Lanjutkan di $name';
        break;
      default:
        if (modifier == 'uturn') {
          text = 'Putar balik';
        } else if (modifier == 'straight' || dir.isEmpty) {
          text = 'Lanjutkan lurus$onRoad';
        } else {
          text = 'Belok $dir$onRoad';
        }
    }

    final loc = maneuver['location'];
    LatLng? location;
    if (loc is List && loc.length >= 2) {
      location = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
    }

    return _RouteStep(
      instruction: text,
      icon: _iconFor(type, modifier),
      distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
      location: location,
    );
  }

  // --- Format ---

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double minutes) {
    final total = minutes.round();
    if (total < 1) return '< 1 menit';
    if (total < 60) return '$total menit';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '$h jam' : '$h jam $m menit';
  }

  String _formatEta(double minutes) {
    final t = DateTime.now().add(Duration(minutes: minutes.round()));
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh.$mm';
  }

  // ---------------------------------------------------------------------------
  // Google Maps
  // ---------------------------------------------------------------------------

  /// Membuka Google Maps. Tanpa `origin`, Google Maps otomatis memakai lokasi
  /// pengguna saat ini, sehingga tombol ini juga berfungsi tanpa GPS di aplikasi.
  Future<void> _openGoogleMaps(
    _Destination destination, {
    _TravelMode? mode,
  }) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination':
          '${destination.location.latitude},${destination.location.longitude}',
      'travelmode': (mode ?? _travelMode).googleMode,
    });

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showMessage('Google Maps tidak dapat dibuka pada perangkat ini.');
      }
    } catch (e) {
      debugPrint('Gagal membuka Google Maps: $e');
      _showMessage('Google Maps tidak dapat dibuka. Coba lagi.');
    }
  }

  // ---------------------------------------------------------------------------
  // Detail destinasi
  // ---------------------------------------------------------------------------

  void _showDestination(_Destination destination) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final isSaved = _savedIds.contains(destination.id);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(destination.city, style: const TextStyle(color: safarGreen)),
              const SizedBox(height: 12),
              Text(destination.description),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showRoute(destination);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: safarGreen,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Lihat rute dari lokasiku'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openGoogleMaps(destination);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: safarGreen,
                    side: const BorderSide(color: safarGreen),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Buka di Google Maps'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _toggleSavedAny(destination);
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                      },
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(
                        isSaved ? 'Hapus dari tersimpan' : 'Simpan lokasi',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Pusatkan peta',
                    onPressed: () {
                      if (_mapReady) {
                        _mapController.move(destination.location, 16);
                      }
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.my_location),
                    style: IconButton.styleFrom(backgroundColor: safarGreen),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final allDestinations = [..._destinations, ..._customDestinations];
    final visibleDestinations = allDestinations.where((destination) {
      final sameCity = destination.city == _selectedCity;
      final saved = _savedIds.contains(destination.id);
      return sameCity && (!_showSavedOnly || saved);
    }).toList();

    final markers = <Marker>[
      ...visibleDestinations.map(
        (destination) => Marker(
          point: destination.location,
          width: 58,
          height: 66,
          child: GestureDetector(
            onTap: () => _showDestination(destination),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _savedIds.contains(destination.id)
                      ? Icons.location_on
                      : Icons.location_on_outlined,
                  color: _savedIds.contains(destination.id)
                      ? Colors.orange
                      : safarGreen,
                  size: 36,
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    destination.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_selectedSearchResult != null &&
          !visibleDestinations.any(
            (item) => item.id == _selectedSearchResult!.id,
          ))
        Marker(
          point: _selectedSearchResult!.location,
          width: 54,
          height: 58,
          child: GestureDetector(
            onTap: () => _showDestination(_selectedSearchResult!),
            child: const Icon(
              Icons.location_pin,
              color: Colors.deepOrange,
              size: 46,
            ),
          ),
        ),
      if (_hasRoute)
        Marker(
          point: _routeDestination!.location,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: const Icon(Icons.flag_circle, color: Colors.red, size: 40),
        ),
      if (_currentPosition != null)
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 44,
          height: 44,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 34),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Peta Lokasi'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCity,
                        decoration: const InputDecoration(
                          labelText: 'Pilih wilayah',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Makkah',
                            child: Text('Makkah'),
                          ),
                          DropdownMenuItem(
                            value: 'Madinah',
                            child: Text('Madinah'),
                          ),
                          DropdownMenuItem(
                            value: 'Turki',
                            child: Text('Turki (Istanbul)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _resetRoute();
                          setState(() {
                            _selectedCity = value;
                            _showSavedOnly = false;
                            _searchResults = [];
                            _selectedSearchResult = null;
                            _searchController.clear();
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _focusCity();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Tampilkan lokasiku',
                      onPressed: _loadingLocation ? null : _showCurrentLocation,
                      style: IconButton.styleFrom(backgroundColor: safarGreen),
                      icon: _loadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchPlaces(),
                        decoration: InputDecoration(
                          hintText: 'Cari tempat di $_selectedCity...',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          suffixIcon: IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _searching ? null : _searchPlaces,
                      style: FilledButton.styleFrom(
                        backgroundColor: safarGreen,
                        padding: const EdgeInsets.all(14),
                      ),
                      child: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: safarGreen,
                          ),
                          title: Text(
                            result.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                          trailing: IconButton(
                            tooltip: _savedIds.contains(result.id)
                                ? 'Tersimpan'
                                : 'Simpan lokasi',
                            icon: Icon(
                              _savedIds.contains(result.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            onPressed: () => _toggleSavedAny(result),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: _showSavedOnly,
                avatar: const Icon(Icons.bookmark_border, size: 18),
                label: const Text('Lokasi tersimpan'),
                selectedColor: safarLightGreen,
                onSelected: (value) {
                  setState(() {
                    _showSavedOnly = value;
                    _searchResults = [];
                    _selectedSearchResult = null;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _makkahCenter,
                    initialZoom: 12,
                    onMapReady: () {
                      _mapReady = true;
                      _focusCity();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.projek_akhir_pam',
                    ),
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          // Garis putih di bawah sebagai bingkai rute.
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 9,
                            color: Colors.white,
                          ),
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: const Color(0xFF1A73E8),
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          '© OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loadingRoute && !_hasRoute)
                  Positioned(
                    left: 12,
                    right: 76,
                    top: 12,
                    child: Card(
                      elevation: 4,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: safarGreen,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Text('Memuat rute...')),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in_map',
                        tooltip: 'Perbesar peta',
                        onPressed: () {
                          final camera = _mapController.camera;
                          _mapController.move(camera.center, camera.zoom + 1);
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out_map',
                        tooltip: 'Perkecil peta',
                        onPressed: () {
                          final camera = _mapController.camera;
                          _mapController.move(camera.center, camera.zoom - 1);
                        },
                        child: const Icon(Icons.remove),
                      ),
                      if (_hasRoute) ...[
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'follow_me_map',
                          tooltip: _followMe
                              ? 'Berhenti mengikuti lokasi'
                              : 'Ikuti lokasiku',
                          backgroundColor: _followMe
                              ? safarGreen
                              : Colors.white,
                          foregroundColor: _followMe
                              ? Colors.white
                              : safarGreen,
                          onPressed: () {
                            setState(() => _followMe = !_followMe);
                            final p = _currentPosition;
                            if (_followMe && p != null && _mapReady) {
                              _mapController.move(
                                LatLng(p.latitude, p.longitude),
                                16,
                              );
                            }
                          },
                          child: Icon(
                            _followMe ? Icons.gps_fixed : Icons.gps_not_fixed,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showSavedOnly && visibleDestinations.isEmpty)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Belum ada lokasi tersimpan di wilayah ini.',
                      ),
                    ),
                  ),
                if (_hasRoute)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _buildRoutePanel(),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: const Text(
              'Pilih penanda pada peta untuk melihat informasi, rute, dan menyimpan destinasi. Data peta © OpenStreetMap contributors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePanel() {
    final destination = _routeDestination!;
    final minutes = _routeDurationMinutes!;
    final km = _routeDistanceKm!;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingRoute)
            const LinearProgressIndicator(minHeight: 3, color: safarGreen)
          else
            const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ke ${destination.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDuration(minutes),
                            style: const TextStyle(
                              color: safarGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${_formatDistance(km * 1000)} • tiba ±${_formatEta(minutes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup rute',
                  onPressed: _resetRoute,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final mode in _TravelMode.values)
                  ChoiceChip(
                    avatar: Icon(
                      mode.icon,
                      size: 18,
                      color: mode == _travelMode ? safarGreen : Colors.black54,
                    ),
                    label: Text(mode.label),
                    selected: mode == _travelMode,
                    selectedColor: safarLightGreen,
                    visualDensity: VisualDensity.compact,
                    onSelected: _loadingRoute
                        ? null
                        : (_) => _changeTravelMode(mode),
                  ),
              ],
            ),
          ),
          if (_showSteps)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                itemCount: _routeSteps.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final step = _routeSteps[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(step.icon, color: safarGreen),
                    title: Text(
                      step.instruction,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: step.distanceMeters > 0
                        ? Text(
                            _formatDistance(step.distanceMeters),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          )
                        : null,
                    onTap: step.location == null || !_mapReady
                        ? null
                        : () => _mapController.move(step.location!, 17),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _routeSteps.isEmpty
                        ? null
                        : () => setState(() => _showSteps = !_showSteps),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: safarGreen,
                      side: const BorderSide(color: safarGreen),
                    ),
                    icon: Icon(
                      _showSteps ? Icons.expand_more : Icons.list_alt,
                      size: 18,
                    ),
                    label: Text(_showSteps ? 'Sembunyikan' : 'Langkah'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _openGoogleMaps(destination),
                    style: FilledButton.styleFrom(backgroundColor: safarGreen),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigasi di Google Maps'),
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

class _Destination {
  final String id;
  final String name;
  final String city;
  final String description;
  final LatLng location;

  const _Destination({
    required this.id,
    required this.name,
    required this.city,
    required this.description,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'description': description,
    'latitude': location.latitude,
    'longitude': location.longitude,
  };

  factory _Destination.fromJson(Map<String, dynamic> json) {
    return _Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      description: json['description'] as String,
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
    );
  }
}
