import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);
const int _maxImageBytes = 5 * 1024 * 1024;

class TanyaSafarMateAiPage extends StatefulWidget {
  const TanyaSafarMateAiPage({super.key});

  @override
  State<TanyaSafarMateAiPage> createState() => _TanyaSafarMateAiPageState();
}

class _TanyaSafarMateAiPageState extends State<TanyaSafarMateAiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Assalamualaikum! Aku SafarMate AI. Silakan tanyakan seputar persiapan perjalanan, panduan Umrah, atau informasi yang kamu butuhkan.',
      isUser: false,
    ),
  ];

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final rows = await _supabase
          .from('safarmate_ai_messages')
          .select('id, role, content, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: true)
          .order('id', ascending: true);

      if (!mounted) return;
      final history = rows.map<_ChatMessage>((row) {
        return _ChatMessage(
          text: row['content'] as String,
          isUser: row['role'] == 'user',
        );
      }).toList();

      if (history.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(history);
        });
        _scrollToBottom();
      }
    } catch (error) {
      debugPrint('Gagal memuat riwayat chat: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Riwayat chat gagal dimuat. Periksa koneksi dan izin database.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveMessage({
    required String userId,
    required String role,
    required String content,
  }) async {
    await _supabase.from('safarmate_ai_messages').insert({
      'user_id': userId,
      'role': role,
      'content': content,
    });
  }

  Future<void> _chooseImageSource() async {
    if (_isLoading || _isLoadingHistory) return;

    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tambahkan gambar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: safarLightGreen,
                  child: Icon(Icons.photo_library_outlined, color: safarGreen),
                ),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: safarLightGreen,
                  child: Icon(Icons.camera_alt_outlined, color: safarGreen),
                ),
                title: const Text('Ambil foto dengan kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;

      final imageBytes = await image.readAsBytes();
      if (imageBytes.length > _maxImageBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ukuran gambar terlalu besar. Pilih gambar maksimal 5 MB.',
            ),
          ),
        );
        return;
      }

      final extension = image.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format gambar harus JPG, PNG, atau WebP.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = imageBytes;
      });
    } catch (error) {
      debugPrint('Gagal memilih gambar: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar tidak dapat dibuka. Coba lagi.'),
          ),
        );
      }
    }
  }

  String _mimeTypeFor(XFile image) {
    final extension = image.name.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final image = _selectedImage;

    if ((text.isEmpty && image == null) || _isLoading || _isLoadingHistory) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login tidak ditemukan. Silakan login kembali.'),
        ),
      );
      return;
    }

    String? imageBase64;
    String? mimeType;
    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        if (bytes.length > _maxImageBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ukuran gambar maksimal 5 MB.')),
          );
          return;
        }
        imageBase64 = base64Encode(bytes);
        mimeType = _mimeTypeFor(image);
      } catch (error) {
        debugPrint('Gagal membaca gambar: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar gagal dibaca. Silakan pilih ulang.'),
          ),
        );
        return;
      }
    }

    final userId = user.id;
    final visibleText = text.isEmpty ? 'Tolong jelaskan gambar ini.' : text;
    final historyText = image == null
        ? visibleText
        : '$visibleText\n[Gambar dilampirkan]';

    setState(() {
      _messages.add(
        _ChatMessage(
          text: visibleText,
          isUser: true,
          imageBytes: image == null ? null : _selectedImageBytes,
        ),
      );
      _controller.clear();
      _selectedImage = null;
      _selectedImageBytes = null;
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      await _saveMessage(userId: userId, role: 'user', content: historyText);
    } catch (error) {
      debugPrint('Gagal menyimpan pertanyaan: $error');
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Pertanyaan belum berhasil disimpan. Periksa koneksi dan izin database, lalu coba lagi.',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final body = <String, dynamic>{'message': visibleText};
      if (imageBase64 != null && mimeType != null) {
        body['imageBase64'] = imageBase64;
        body['mimeType'] = mimeType;
      }

      final response = await _supabase.functions.invoke(
        'safarmate-ai',
        body: body,
      );

      final data = response.data;
      final answer = data is Map ? data['answer']?.toString() : null;
      if (response.status < 200 ||
          response.status >= 300 ||
          answer == null ||
          answer.trim().isEmpty) {
        final detail = data is Map ? data['error']?.toString() : null;
        throw Exception(detail ?? 'Respons AI tidak tersedia.');
      }

      final answerText = answer.trim();
      try {
        await _saveMessage(
          userId: userId,
          role: 'assistant',
          content: answerText,
        );
      } catch (error) {
        debugPrint('Gagal menyimpan jawaban AI: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Jawaban tampil, tetapi gagal disimpan ke riwayat.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: answerText, isUser: false));
      });
    } catch (error) {
      debugPrint('Gagal mendapatkan jawaban AI: $error');
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Maaf, SafarMate AI belum dapat menjawab saat ini. Pastikan koneksi internet tersedia dan layanan AI berfungsi, lalu coba lagi.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isUser ? safarGreen : Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  message.imageBytes!,
                  width: 240,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 220,
                    child: Text('Gambar dikirim (pratinjau tidak tersedia).'),
                  ),
                ),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.text.isNotEmpty)
              isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(color: Colors.white, height: 1.45),
                    )
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.45,
                        ),
                        h1: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        h4: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        em: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        listBullet: const TextStyle(color: Colors.black87),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        title: const Text('Tanya SafarMate AI'),
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isLoadingHistory)
            const LinearProgressIndicator(color: safarGreen, minHeight: 2),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: safarGreen,
                        ),
                      ),
                    ),
                  );
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: safarLightGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Gambar siap dikirim',
                              style: TextStyle(
                                color: safarGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus gambar',
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    _selectedImage = null;
                                    _selectedImageBytes = null;
                                  }),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: safarGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Tambah gambar',
                        onPressed: _isLoading || _isLoadingHistory
                            ? null
                            : _chooseImageSource,
                        style: IconButton.styleFrom(
                          backgroundColor: safarLightGreen,
                          foregroundColor: safarGreen,
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Tulis pertanyaan seputar umrah...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isLoading || _isLoadingHistory
                            ? null
                            : _sendMessage,
                        style: IconButton.styleFrom(
                          backgroundColor: safarGreen,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
  });
}
