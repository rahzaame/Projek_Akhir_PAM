import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/schedule_service.dart';
import '../services/trip_service.dart';
import '../utils/format_utils.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class TanyaSafarMateAiPage extends StatefulWidget {
  const TanyaSafarMateAiPage({super.key});

  @override
  State<TanyaSafarMateAiPage> createState() => _TanyaSafarMateAiPageState();
}

class _TanyaSafarMateAiPageState extends State<TanyaSafarMateAiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final _supabase = Supabase.instance.client;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Assalamu’alaikum! Aku SafarMate AI. '
          'Silakan tanyakan seputar persiapan perjalanan, '
          'panduan Umrah, atau informasi yang kamu butuhkan.',
      isUser: false,
    ),
  ];

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

  // Memuat riwayat berdasarkan akun yang sedang login.
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
              'Riwayat chat gagal dimuat. Periksa koneksi dan coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
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

  Future<Map<String, dynamic>?> _buildUserContext() async {
    try {
      final trip = await TripService().fetchFeaturedTrip();
      if (trip == null) return null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final schedules = await ScheduleService().fetchSchedules();
      final upcoming = schedules
          .where((row) {
            final date = parseDbDate(row['schedule_date']);
            return date != null && !date.isBefore(today);
          })
          .take(3)
          .map((row) => '${row['schedule_date']} ${row['title']}')
          .toList();

      return {
        'trip_name': trip['trip_name'],
        'status': trip['status'],
        'departure_date': trip['departure_date'],
        'return_date': trip['return_date'],
        'origin_city': trip['origin_city'],
        'participant_count': trip['participant_count'],
        'upcoming_schedules': upcoming,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading || _isLoadingHistory) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login tidak ditemukan. Silakan login kembali.'),
        ),
      );
      return;
    }

    final userId = user.id;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      await _saveMessage(userId: userId, role: 'user', content: text);
    } catch (error) {
      debugPrint('Gagal menyimpan pertanyaan: $error');

      if (mounted) {
        setState(() {
          _messages.add(
            const _ChatMessage(
              text:
                  'Pertanyaan belum berhasil disimpan. '
                  'Periksa koneksi dan izin database, lalu coba lagi.',
              isUser: false,
            ),
          );
          _isLoading = false;
        });

        _scrollToBottom();
      }

      return;
    }

    try {
      final userContext = await _buildUserContext();

      final response = await _supabase.functions.invoke(
        'safarmate-ai',
        body: {
          'message': text,
          if (userContext != null) 'context': userContext,
        },
      );

      final data = response.data;
      final answer = data is Map ? data['answer']?.toString() : null;

      if (response.status < 200 ||
          response.status >= 300 ||
          answer == null ||
          answer.trim().isEmpty) {
        throw Exception('Respons AI tidak tersedia.');
      }

      final answerText = answer.trim();

      // Jawaban tetap ditampilkan meskipun penyimpanan jawaban gagal.
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
            text:
                'Maaf, SafarMate AI belum dapat menjawab saat ini. '
                'Pastikan koneksi internet tersedia dan layanan AI '
                'berfungsi, lalu coba lagi.',
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

                final message = _messages[index];

                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: message.isUser ? safarGreen : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: message.isUser
                        ? Text(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                            ),
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
                              listBullet: const TextStyle(
                                color: Colors.black87,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
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

  const _ChatMessage({required this.text, required this.isUser});
}
