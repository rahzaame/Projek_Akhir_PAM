import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_page.dart';
import 'database_test_page.dart';
import 'login_page.dart';

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

  final List<String> _titles = const [
    'SafarMate',
    'Panduan Ibadah',
    'Peta & Kiblat',
    'Keuangan',
    'Profil',
  ];

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
    final email = user?.email ?? '';
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
              const CircleAvatar(
                radius: 25,
                backgroundColor: safarLightGreen,
                child: Icon(Icons.person_rounded, color: safarGreen, size: 30),
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
                () => _showComingSoon('Checklist Persiapan'),
              ),
              _homeShortcut(
                Icons.calendar_month_rounded,
                'Jadwal',
                'Agenda perjalanan',
                () => _showComingSoon('Jadwal Perjalanan'),
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
          () => _showComingSoon('Tata Cara Umrah'),
        ),
        _featureTile(
          Icons.volunteer_activism_rounded,
          'Doa dan Dzikir',
          'Doa harian selama di Tanah Suci',
          () => _showComingSoon('Doa dan Dzikir'),
        ),
        _featureTile(
          Icons.lightbulb_outline_rounded,
          'Tips Perjalanan',
          'Persiapan praktis untuk jemaah',
          () => _showComingSoon('Tips Perjalanan'),
        ),
        _featureTile(
          Icons.smart_toy_outlined,
          'Tanya SafarMate AI',
          'Asisten AI untuk pertanyaan seputar Umrah',
          () => _showComingSoon('Asisten AI'),
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
        _featureTile(
          Icons.link_rounded,
          'Riwayat Blockchain',
          'Konsep pencatatan transaksi sederhana',
          () => _showComingSoon('Riwayat Blockchain'),
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
            leading: const CircleAvatar(
              radius: 28,
              backgroundColor: safarLightGreen,
              child: Icon(Icons.person_rounded, color: safarGreen, size: 32),
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
        _featureTile(
          Icons.verified_user_outlined,
          'Riwayat Blockchain',
          'Lihat catatan transaksi digital',
          () => _showComingSoon('Riwayat Blockchain'),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
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
