import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometric_credentials.dart';
import '../services/biometric_preferences.dart';
import '../services/biometric_service.dart';
import '../services/supabase_service.dart';
import 'admin_voucher_page.dart';
import 'riwayat_blockchain_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'packages_page.dart';
import 'booking_history_page.dart';
import 'checklist_page.dart';
import 'itinerary_page.dart';
import 'admin_itinerary_page.dart';
import 'admin_packages_page.dart';
import 'saran_kesan_page.dart';
import '../services/package_service.dart';
import 'tata_cara_umrah_page.dart';
import 'doa_dan_dzikir_page.dart';
import 'tips_perjalanan_page.dart';
import 'tanya_safarmate_ai_page.dart';
import 'peta_lokasi_page.dart';
import 'kompas_kiblat_page.dart';
import 'sensor_perangkat_page.dart';
import 'my_schedule.dart';
import 'konversi_mata_uang.dart';
import 'zona_waktu.dart';
import 'catat_pengeluaran.dart';
import 'quiz_Page.dart';
import 'notification_setting.dart';
import 'admin_booking_page.dart';
import '../widgets/trip_hero_card.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarBackground = Color(0xFFF7F8F5);
const Color safarLightGreen = Color(0xFFE1F2E8);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  int _homeTick = 0; // naik setiap kali beranda perlu memuat ulang ringkasan
  bool _isAdmin = false;

  String? _displayName;
  bool _isLoadingName = true;

  String? _profilePhotoUrl;
  bool _isLoadingPhoto = true;

  final List<String> _titles = const [
    'SafarMate',
    'Panduan Ibadah',
    'Peta & Kiblat',
    'Alat Perjalanan',
    'Profil',
  ];

  final _biometricPreferences = BiometricPreferences();
  final _biometricService = BiometricService();
  final _biometricCredentials = BiometricCredentials();

  bool _biometricEnabled = false;
  bool _isLoadingBiometric = true;
  bool _isUpdatingBiometric = false;

  Future<void> _loadBiometricPreference() async {
    try {
      final enabled = await _biometricPreferences.isEnabled();

      if (!mounted) return;

      setState(() {
        _biometricEnabled = enabled;
        _isLoadingBiometric = false;
      });
    } catch (e) {
      debugPrint('Gagal membaca pengaturan biometrik: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingBiometric = false;
      });
    }
  }

  Future<String?> _askPassword() async {
    final controller = TextEditingController();
    bool hide = true;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Konfirmasi password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan password akunmu agar bisa masuk dengan biometrik '
                'dari halaman login.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: hide,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => hide = !hide),
                    icon: Icon(
                      hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: safarGreen),
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_isUpdatingBiometric) return;

    setState(() {
      _isUpdatingBiometric = true;
    });

    void snack(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      if (value) {
        // 1. Perangkat harus punya biometrik yang terdaftar.
        final status = await _biometricService.status();
        if (status != BiometricStatus.available) {
          snack(_biometricService.messageFor(status));
          return;
        }

        final email = Supabase.instance.client.auth.currentUser?.email;
        if (email == null || email.isEmpty) {
          snack('Email akun tidak ditemukan. Silakan login ulang.');
          return;
        }

        // 2. Konfirmasi password, lalu pastikan benar.
        final password = await _askPassword();
        if (password == null || password.isEmpty) return;

        try {
          await SupabaseService().signIn(email: email, password: password);
        } on AuthException {
          snack('Password salah. Login biometrik tidak diaktifkan.');
          return;
        }

        // 3. Uji biometrik sekali.
        final ok = await _biometricService.authenticate(
          reason: 'Verifikasi untuk mengaktifkan login biometrik',
        );
        if (!ok) {
          snack('Verifikasi biometrik gagal.');
          return;
        }

        await _biometricCredentials.save(email: email, password: password);
      } else {
        // Nonaktif: hapus juga kredensial yang tersimpan di perangkat.
        await _biometricCredentials.clear();
      }

      await _biometricPreferences.setEnabled(value);

      if (!mounted) return;

      setState(() {
        _biometricEnabled = value;
      });

      snack(
        value
            ? 'Login biometrik diaktifkan. Kamu bisa memakainya di halaman login.'
            : 'Login biometrik dinonaktifkan.',
      );
    } catch (e) {
      debugPrint('Gagal menyimpan pengaturan biometrik: $e');
      snack('Gagal mengubah pengaturan biometrik.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBiometric = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadProfilePhoto();
    _loadBiometricPreference();
    _loadDisplayName();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isAdmin = profile?['role'] == 'admin';
      });
    } catch (e) {
      debugPrint('Gagal memeriksa role pengguna: $e');
    }
  }

  Future<void> _loadDisplayName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoadingName = false;
      });
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final nameFromProfile = response?['full_name']?.toString().trim();

      final nameFromMetadata = user.userMetadata?['full_name']
          ?.toString()
          .trim();

      String? name;

      if (nameFromProfile != null && nameFromProfile.isNotEmpty) {
        name = nameFromProfile;
      } else if (nameFromMetadata != null && nameFromMetadata.isNotEmpty) {
        name = nameFromMetadata;
      }

      if (!mounted) return;

      setState(() {
        _displayName = name;
        _isLoadingName = false;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Gagal memuat nama pengguna: $e');

      setState(() {
        _displayName = null;
        _isLoadingName = false;
      });
    }
  }

  Future<void> _loadProfilePhoto() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = null;
        _isLoadingPhoto = false;
      });
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('profile_photo')
          .eq('id', user.id)
          .maybeSingle();

      final photoUrl = response?['profile_photo']?.toString().trim();

      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = (photoUrl != null && photoUrl.isNotEmpty)
            ? photoUrl
            : null;
        _isLoadingPhoto = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat foto profil: $e');

      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = null;
        _isLoadingPhoto = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu harus login kembali untuk menggunakan SafarMate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: safarGreen),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _openProfileDetails() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  void _openPackages() {
    _openFeaturePage(const PackagesPage());
  }

  void _openChecklist() {
    _openFeaturePage(const ChecklistPage());
  }

  void _openAdminPackages() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AdminPackagesPage()));
  }

  Future<void> _openAdminItinerary() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AdminItineraryPage()));
  }

  void _openBookingHistory() {
    _openFeaturePage(const BookingHistoryPage());
  }

  // Menu Jadwal: tampilkan daftar paket terlebih dahulu.
  Future<void> _openItineraryPackages() async {
    try {
      final packages = await PackageService().getPackages();

      if (!mounted) return;

      if (packages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada paket perjalanan tersedia.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (pageContext) => Scaffold(
            appBar: AppBar(
              title: const Text('Pilih Jadwal Perjalanan'),
              backgroundColor: safarGreen,
              foregroundColor: Colors.white,
            ),
            body: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final package = packages[index];

                final name = package['name']?.toString() ?? 'Paket Umrah';
                final type = package['package_type']?.toString() ?? '';
                final duration = package['duration_days']?.toString() ?? '-';

                final typeLabel = type == 'umrah_plus_turki'
                    ? 'Umrah Plus Turki'
                    : 'Umrah Reguler';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: safarLightGreen,
                      child: Icon(Icons.calendar_month, color: safarGreen),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$typeLabel • $duration hari'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        pageContext,
                        MaterialPageRoute(
                          builder: (_) => ItineraryPage(package: package),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memuat paket: $e')));
    }
  }

  Future<void> _openFeaturePage(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() => _homeTick++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      _buildPanduan(),
      _buildPeta(),
      _buildKeuangan(),
      _buildProfileMenu(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: safarLightGreen,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Panduan',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Peta',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: 'Alat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final greetingName = (_displayName != null && _displayName!.isNotEmpty)
        ? _displayName!
        : 'Sahabat SafarMate';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _homeTick++);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: safarLightGreen,
                  backgroundImage:
                      (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(_profilePhotoUrl!)
                      : null,
                  onBackgroundImageError: _profilePhotoUrl != null
                      ? (exception, stackTrace) {
                          debugPrint('Gagal memuat foto profil: $exception');
                        }
                      : null,
                  child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                      ? const Icon(
                          Icons.person_rounded,
                          color: safarGreen,
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assalamu’alaikum,',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      Text(
                        greetingName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Pengaturan notifikasi',
                  onPressed: () =>
                      _openFeaturePage(const NotificationSettingsPage()),
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: safarGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isAdmin)
              _adminShortcuts()
            else
              TripHeroCard(
                key: ValueKey('hero-$_homeTick'),
                onOpenPackages: _openPackages,
                onOpenBookings: _openBookingHistory,
                onOpenChecklist: _openChecklist,
                onOpenSchedule: () => _openFeaturePage(const MySchedulePage()),
              ),

            const SizedBox(height: 26),
            const Text(
              'Akses cepat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _quickAction(
                  Icons.event_note_rounded,
                  'Agenda',
                  () => _openFeaturePage(const MySchedulePage()),
                ),
                _quickAction(
                  Icons.checklist_rounded,
                  'Checklist',
                  _openChecklist,
                ),
                _quickAction(
                  Icons.receipt_long_rounded,
                  'Pengeluaran',
                  () => _openFeaturePage(const ExpensePage()),
                ),
                _quickAction(
                  Icons.auto_awesome_rounded,
                  'Tanya AI',
                  () => _openFeaturePage(const TanyaSafarMateAiPage()),
                ),
              ],
            ),

            const SizedBox(height: 26),
            const Text(
              'Jelajahi',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _featureTile(
              Icons.flight_takeoff_rounded,
              'Paket Umrah',
              'Umrah Reguler dan Umrah Plus Turki',
              _openPackages,
            ),
            _featureTile(
              Icons.route_rounded,
              'Itinerary Perjalanan',
              'Lihat rencana harian setiap paket',
              _openItineraryPackages,
            ),
            _featureTile(
              Icons.history_rounded,
              'Riwayat Pemesanan',
              'Status, dan detail pemesanan',
              _openBookingHistory,
            ),
            _featureTile(
              Icons.quiz_outlined,
              'Kuis Manasik',
              'Uji pengetahuan manasik dan destinasi',
              () => _openFeaturePage(const QuizPage()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminShortcuts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E4A37),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panel admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kelola pemesanan, paket, itinerary, dan voucher.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 10),
          for (final item in [
            (
              Icons.fact_check_outlined,
              'Kelola Pemesanan',
              () => _openFeaturePage(const AdminBookingPage()),
            ),
            (
              Icons.inventory_2_outlined,
              'Kelola Paket Umrah',
              () => _openFeaturePage(const AdminPackagesPage()),
            ),
            (
              Icons.edit_calendar_rounded,
              'Kelola Itinerary',
              () => _openFeaturePage(const AdminItineraryPage()),
            ),
            (
              Icons.card_giftcard,
              'Kelola Voucher',
              () => _openFeaturePage(const AdminVoucherPage()),
            ),
          ])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$1, color: const Color(0xFFE9C46A)),
              title: Text(item.$2, style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: item.$3,
            ),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6DE)),
                ),
                child: Icon(icon, color: safarGreen, size: 26),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanduan() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _featureTile(
          Icons.menu_book_rounded,
          'Tata Cara Umrah',
          'Panduan langkah demi langkah',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TataCaraUmrahPage()),
          ),
        ),
        _featureTile(
          Icons.volunteer_activism_rounded,
          'Doa dan Dzikir',
          'Doa harian selama di Tanah Suci',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DoaDanDzikirPage()),
          ),
        ),
        _featureTile(
          Icons.lightbulb_outline_rounded,
          'Tips Perjalanan',
          'Persiapan praktis untuk jemaah',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TipsPerjalananPage()),
          ),
        ),
        _featureTile(
          Icons.smart_toy_outlined,
          'Tanya SafarMate AI',
          'Asisten AI untuk pertanyaan seputar Umrah',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TanyaSafarMateAiPage()),
          ),
        ),
        _featureTile(
          Icons.quiz_outlined,
          'Kuis Manasik',
          'Uji pengetahuan manasik dan destinasi',
          () => _openFeaturePage(const QuizPage()),
        ),
      ],
    );
  }

  Widget _buildPeta() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _featureTile(
          Icons.map_outlined,
          'Peta Lokasi',
          'Lihat destinasi penting di Makkah dan Madinah',
          () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PetaLokasiPage()));
          },
        ),
        _featureTile(
          Icons.explore_outlined,
          'Kompas Kiblat',
          'Arahkan perangkat untuk membantu menentukan arah',
          () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const KompasKiblatPage()));
          },
        ),
        _featureTile(
          Icons.screen_rotation_outlined,
          'Sensor Perangkat',
          'Fitur orientasi dan accelerometer',
          () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SensorPerangkatPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKeuangan() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _featureTile(
          Icons.calendar_month_rounded,
          'Agenda Saya',
          'Atur jadwal dan pengingat pribadi',
          () => _openFeaturePage(const MySchedulePage()),
        ),
        _featureTile(
          Icons.currency_exchange_rounded,
          'Konversi Mata Uang',
          'IDR, SAR, dan TRY',
          () => _openFeaturePage(const CurrencyConverterPage()),
        ),
        _featureTile(
          Icons.access_time_rounded,
          'Konversi Zona Waktu',
          'WIB, WITA, WIT, London, dan Arab Saudi',
          () => _openFeaturePage(const TimeConverterPage()),
        ),
        _featureTile(
          Icons.receipt_long_outlined,
          'Catatan Pengeluaran',
          'Catat pengeluaran dan lihat ringkasan anggaran',
          () => _openFeaturePage(const ExpensePage()),
        ),
      ],
    );
  }

  Widget _buildProfileMenu() {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name']?.toString();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),

            leading: CircleAvatar(
              radius: 28,
              backgroundColor: safarLightGreen,
              backgroundImage:
                  (_profilePhotoUrl != null &&
                      _profilePhotoUrl!.trim().isNotEmpty)
                  ? NetworkImage(_profilePhotoUrl!.trim())
                  : null,
              onBackgroundImageError: _profilePhotoUrl != null
                  ? (exception, stackTrace) {
                      debugPrint('Gagal memuat foto profil: $exception');
                    }
                  : null,
              child:
                  (_profilePhotoUrl == null || _profilePhotoUrl!.trim().isEmpty)
                  ? const Icon(
                      Icons.person_rounded,
                      color: safarGreen,
                      size: 32,
                    )
                  : null,
            ),

            title: Text(
              _displayName != null && _displayName!.trim().isNotEmpty
                  ? _displayName!
                  : 'Pengguna SafarMate',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(user?.email ?? '-'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openProfileDetails,
          ),
        ),
        const SizedBox(height: 16),
        _featureTile(
          Icons.manage_accounts_outlined,
          'Informasi Profil',
          'Edit nama, username, telepon, dan tanggal lahir',
          _openProfileDetails,
        ),
        Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: SwitchListTile(
            secondary: const Icon(
              Icons.fingerprint,
              color: safarGreen,
              size: 29,
            ),
            title: const Text(
              'Login Biometrik',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isLoadingBiometric
                  ? 'Memuat pengaturan...'
                  : _biometricEnabled
                  ? 'Aktif'
                  : 'Nonaktif',
            ),
            value: _biometricEnabled,
            onChanged: _isLoadingBiometric || _isUpdatingBiometric
                ? null
                : _toggleBiometric,
            activeTrackColor: safarGreen,
          ),
        ),
        _featureTile(
          Icons.feedback_outlined,
          'Saran dan Kesan',
          'Mata kuliah Pemrograman Aplikasi Mobile',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SaranKesanPage()),
            );
          },
        ),
        _featureTile(
          Icons.notifications_none_rounded,
          'Notifikasi',
          'Pengingat agenda, keberangkatan, dan checklist',
          () => _openFeaturePage(const NotificationSettingsPage()),
        ),
        // Hanya muncul untuk akun jamaah (bukan admin).
        if (!_isAdmin)
          _featureTile(
            Icons.verified_user_outlined,
            'Voucher Saya',
            'Lihat dan unduh voucher perjalanan Anda',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiwayatBlockchainPage(),
                ),
              );
            },
          ),

        if (_isAdmin) ...[
          _featureTile(
            Icons.fact_check_outlined,
            'Kelola Pemesanan',
            'Lihat pemesanan jamaah dan ubah statusnya',
            () => _openFeaturePage(const AdminBookingPage()),
          ),
          _featureTile(
            Icons.card_giftcard,
            'Kelola Voucher Blockchain',
            'Buat dan verifikasi voucher PDF',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminVoucherPage()),
              );
            },
          ),
          _featureTile(
            Icons.inventory_2_outlined,
            'Kelola Paket Umrah',
            'Tambah, edit, dan hapus paket perjalanan',
            _openAdminPackages,
          ),
          _featureTile(
            Icons.edit_calendar_rounded,
            'Kelola Itinerary',
            'Tambah, edit, dan hapus jadwal perjalanan',
            _openAdminItinerary,
          ),
        ],

        const SizedBox(height: 20),

        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _featureTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: safarLightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: safarGreen, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
        onTap: onTap,
      ),
    );
  }
}
