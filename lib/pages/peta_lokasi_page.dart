import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class PetaLokasiPage extends StatefulWidget {
  /// Bila diisi (misalnya dari itinerary), peta langsung mencari lokasi ini.
  final String? initialQuery;

  const PetaLokasiPage({super.key, this.initialQuery});

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

  static const LatLng _makkahCenter = LatLng(21.4225, 39.8262);
  static const LatLng _madinahCenter = LatLng(24.4672, 39.6111);
  static const LatLng _turkeyCenter = LatLng(41.0082, 28.9784);

  static const String _savedKey = 'safarmate_saved_destinations';
  static const String _customKey = 'safarmate_custom_destinations';

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

    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      final lower = query.toLowerCase();
      if (lower.contains('madinah') || lower.contains('medina')) {
        _selectedCity = 'Madinah';
      } else if (lower.contains('istanbul') || lower.contains('turki')) {
        _selectedCity = 'Turki';
      }
      _searchController.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchPlaces();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

    final country = _selectedCity == 'Turki' ? 'Turkey' : 'Saudi Arabia';
    final city = _selectedCity == 'Turki' ? 'Istanbul' : _selectedCity;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$query, $city, $country',
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '1',
        'accept-language': 'id,en',
        'countrycodes': _selectedCity == 'Turki' ? 'tr' : 'sa',
      });

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'SafarMateFlutterApp/1.0 (location search feature)',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Layanan pencarian memberi status ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final results = <_Destination>[];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = item['display_name']?.toString();

        if (lat == null || lon == null || displayName == null) continue;

        final name = item['name']?.toString().trim().isNotEmpty == true
            ? item['name'].toString()
            : displayName.split(',').first;

        final id =
            'search_${item['osm_type'] ?? 'place'}_${item['osm_id'] ?? item['place_id']}';

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
        _showMessage('Lokasi tidak ditemukan di wilayah $_selectedCity.');
      }
    } catch (e) {
      debugPrint('Pencarian lokasi gagal: $e');
      _showMessage('Pencarian gagal. Periksa koneksi internet lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(_Destination destination) {
    setState(() {
      _selectedSearchResult = destination;
      _showSavedOnly = false;
    });
    if (_mapReady) _mapController.move(destination.location, 16);
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

    setState(() {
      _customDestinations = updated;
    });
    await _toggleSaved(destination);
  }

  Future<void> _showCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Aktifkan layanan lokasi/GPS perangkat terlebih dahulu.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi belum diberikan.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (destination.id.startsWith('search_')) {
                          if (isSaved) {
                            final updated = Set<String>.from(_savedIds)
                              ..remove(destination.id);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setStringList(
                              _savedKey,
                              updated.toList(),
                            );
                            if (!mounted) return;
                            setState(() => _savedIds = updated);
                          } else {
                            await _saveSearchResult(destination);
                          }
                        } else {
                          await _toggleSaved(destination);
                        }
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
                            onPressed: () async {
                              if (_savedIds.contains(result.id)) {
                                final updated = Set<String>.from(_savedIds)
                                  ..remove(result.id);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setStringList(
                                  _savedKey,
                                  updated.toList(),
                                );
                                if (mounted) {
                                  setState(() => _savedIds = updated);
                                }
                              } else {
                                await _saveSearchResult(result);
                              }
                            },
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
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: const Text(
              'Pilih penanda pada peta untuk melihat informasi dan menyimpan destinasi. Data pencarian © OpenStreetMap contributors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
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
