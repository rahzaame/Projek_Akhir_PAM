import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthController = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  String _email = '';
  String? _profileId;

  XFile? _selectedImage;
  bool _isUploadingPhoto = false;

  final ImagePicker _imagePicker = ImagePicker();
  String? _profilePhoto;

  static const Color _green = Color(0xFF176B50);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('Sesi login tidak ditemukan. Silakan login kembali.');
      return;
    }

    _email = user.email ?? '';

    try {
      final data = await _supabase
          .from('profiles')
          .select(
            'id, full_name, username, phone_number, date_of_birth, profile_photo',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        _showMessage(
          'Data profil belum ditemukan. Periksa data akun di Supabase.',
        );
        setState(() => _isLoading = false);
        return;
      }

      _profileId = data['id']?.toString();
      _fullNameController.text = data['full_name']?.toString() ?? '';
      _usernameController.text = data['username']?.toString() ?? '';
      _phoneController.text = data['phone_number']?.toString() ?? '';
      _birthController.text = data['date_of_birth']?.toString() ?? '';
      _profilePhoto = data['profile_photo']?.toString();

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('Gagal memuat profil: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Silakan login kembali.');
      return;
    }

    if (_profileId == null || _profileId != user.id) {
      _showMessage('ID profil tidak sesuai dengan akun yang login.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabase
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'username': _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            'phone_number': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'date_of_birth': _birthController.text.trim().isEmpty
                ? null
                : _birthController.text.trim(),
          })
          .eq('id', user.id);

      if (!mounted) return;

      _showMessage('Profil berhasil disimpan.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan profil: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Silakan login kembali.');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = image;
        _isUploadingPhoto = true;
      });

      final Uint8List bytes = await image.readAsBytes();
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';

      final filePath =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: extension == 'jpg'
                  ? 'image/jpeg'
                  : 'image/$extension',
            ),
          );

      final photoUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      await _supabase
          .from('profiles')
          .update({'profile_photo': photoUrl})
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _profilePhoto = photoUrl;
        _selectedImage = null;
      });

      _showMessage('Foto profil berhasil diperbarui.');
    } on PostgrestException catch (e) {
      if (mounted) {
        _showMessage('Gagal menyimpan URL foto: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal mengunggah foto: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    DateTime initialDate = DateTime(now.year - 18, now.month, now.day);

    final currentValue = _birthController.text.trim();

    if (currentValue.isNotEmpty) {
      final parsed = DateTime.tryParse(currentValue);
      if (parsed != null) {
        initialDate = parsed;
      }
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (selectedDate != null && mounted) {
      final month = selectedDate.month.toString().padLeft(2, '0');
      final day = selectedDate.day.toString().padLeft(2, '0');

      setState(() {
        _birthController.text = '${selectedDate.year}-$month-$day';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _green),
          suffixIcon: readOnly
              ? const Icon(Icons.calendar_month_outlined)
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = _profilePhoto;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFE1EEE8),
                          backgroundImage: _selectedImage != null
                              ? MemoryImage(
                                  // Foto sementara sebelum upload selesai.
                                  // Lihat catatan di bawah.
                                  Uint8List(0),
                                )
                              : photo != null && photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                        ),
                        const SizedBox(height: 12),

                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isUploadingPhoto
                              ? null
                              : _uploadProfilePhoto,
                          icon: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _isUploadingPhoto
                                ? 'Mengunggah foto...'
                                : 'Ganti Foto Profil',
                          ),
                        ),

                        Text(
                          _fullNameController.text.isEmpty
                              ? 'Nama pengguna'
                              : _fullNameController.text,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Informasi Pribadi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Nama lengkap',
                          icon: Icons.person_outline,
                          hint: 'Masukkan nama lengkap',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          icon: Icons.alternate_email,
                          hint: 'Masukkan username',
                        ),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Nomor telepon',
                          icon: Icons.phone_outlined,
                          hint: 'Contoh: 081234567890',
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          controller: _birthController,
                          label: 'Tanggal lahir',
                          icon: Icons.cake_outlined,
                          hint: 'Pilih tanggal lahir',
                          readOnly: true,
                          onTap: _selectBirthDate,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving ? 'Menyimpan...' : 'Simpan Profil',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
