import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/biometric_preferences.dart';
import 'admin_voucher_page.dart';
import 'riwayat_blockchain_page.dart';
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
import '../services/package_service.dart';
import 'tata_cara_umrah_page.dart';
import 'doa_dan_dzikir_page.dart';
import 'tips_perjalanan_page.dart';
import 'tanya_safarmate_ai_page.dart';

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
  bool _isAdmin = false;

  String? _displayName;
  bool _isLoadingName = true;

  String? _profilePhotoUrl;
  bool _isLoadingPhoto = true;

  final List<String> _titles = const [
    'SafarMate',
    'Panduan Ibadah',
    'Peta & Kiblat',
    'Keuangan',
    'Profil',
  ];

  final _biometricPreferences = BiometricPreferences();

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

  Future<void> _toggleBiometric(bool value) async {
    if (_isUpdatingBiometric) return;

    setState(() {
      _isUpdatingBiometric = true;
    });

    try {
      await _biometricPreferences.setEnabled(value);

      if (!mounted) return;

      setState(() {
        _biometricEnabled = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Login biometrik diaktifkan.'
                : 'Login biometrik dinonaktifkan.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan pengaturan biometrik: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengubah pengaturan biometrik.')),
      );
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
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoadingPhoto = false);
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('profile_photo')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = profile?['profile_photo'] as String?;
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PackagesPage()));
  }

  void _openChecklist() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChecklistPage()));
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BookingHistoryPage()));
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature sedang disiapkan.')));
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
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Keuangan',
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
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name']?.toString().trim();

    final greetingName = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Sahabat SafarMate';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: safarLightGreen,
                backgroundImage:
                    _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                    ? NetworkImage(_profilePhotoUrl!)
                    : null,
                child: _profilePhotoUrl == null || _profilePhotoUrl!.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: safarGreen,
                        size: 30,
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
                      style: TextStyle(color: Colors.black54),
                    ),
                    Text(
                      greetingName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: safarGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showComingSoon('Notifikasi'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: safarGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF176B50), Color(0xFF399477)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mosque_rounded, color: Colors.white, size: 38),
                SizedBox(height: 14),
                Text(
                  'Perjalanan Ibadahmu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Persiapkan perjalanan Umrah dengan lebih '
                  'mudah bersama SafarMate.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Menu Utama',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _homeShortcut(
                Icons.checklist_rounded,
                'Checklist',
                'Persiapan Umrah',
                _openChecklist,
              ),
              _homeShortcut(
                Icons.calendar_month_rounded,
                'Jadwal',
                'Pilih paket perjalanan',
                _openItineraryPackages,
              ),
              _homeShortcut(
                Icons.currency_exchange_rounded,
                'Keuangan',
                'Konversi mata uang',
                () => setState(() => _selectedIndex = 3),
              ),
              _homeShortcut(
                Icons.auto_awesome_rounded,
                'Asisten AI',
                'Tanya seputar Umrah',
                () => setState(() => _selectedIndex = 1),
              ),
              _homeShortcut(
                Icons.flight_takeoff_rounded,
                'Paket Umrah',
                'Umrah Reguler & Plus Turki',
                _openPackages,
              ),
              _homeShortcut(
                Icons.history_rounded,
                'Riwayat Pemesanan',
                'Lihat pemesanan paketmu',
                _openBookingHistory,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _homeShortcut(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: safarGreen, size: 32),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
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
          'Temukan tempat penting di sekitar',
          () => _showComingSoon('Peta Lokasi'),
        ),
        _featureTile(
          Icons.explore_outlined,
          'Kompas Kiblat',
          'Arahkan perangkat untuk membantu menentukan arah',
          () => _showComingSoon('Kompas Kiblat'),
        ),
        _featureTile(
          Icons.screen_rotation_outlined,
          'Sensor Perangkat',
          'Fitur orientasi dan accelerometer',
          () => _showComingSoon('Sensor Perangkat'),
        ),
      ],
    );
  }

  Widget _buildKeuangan() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _featureTile(
          Icons.currency_exchange_rounded,
          'Konversi Mata Uang',
          'IDR, SAR, dan USD',
          () => _showComingSoon('Konversi Mata Uang'),
        ),
        _featureTile(
          Icons.access_time_rounded,
          'Konversi Waktu',
          'WIB, WITA, WIT, dan London',
          () => _showComingSoon('Konversi Waktu'),
        ),
        _featureTile(
          Icons.receipt_long_outlined,
          'Catatan Pengeluaran',
          'Catat kebutuhan selama perjalanan',
          () => _showComingSoon('Catatan Pengeluaran'),
        ),
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
                  _profilePhotoUrl != null &&
                      _profilePhotoUrl!.trim().isNotEmpty
                  ? NetworkImage(_profilePhotoUrl!)
                  : null,
              child:
                  _profilePhotoUrl == null || _profilePhotoUrl!.trim().isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      color: safarGreen,
                      size: 32,
                    )
                  : null,
            ),

            title: Text(
              name != null && name.trim().isNotEmpty
                  ? name
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
          () => _showComingSoon('Saran dan Kesan'),
        ),
        _featureTile(
          Icons.notifications_none_rounded,
          'Notifikasi',
          'Pengingat dan informasi perjalanan',
          () => _showComingSoon('Notifikasi'),
        ),
        _featureTile(
          Icons.settings_outlined,
          'Pengaturan',
          'Pengaturan aplikasi dan akun',
          () => _showComingSoon('Pengaturan'),
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

        // Menu khusus akun admin.
        if (_isAdmin) ...[
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
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: safarGreen, size: 29),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
