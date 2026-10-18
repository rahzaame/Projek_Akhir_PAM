import 'package:flutter/material.dart';

const Color safarGreen = Color(0xFF176B50);
const Color safarLightGreen = Color(0xFFE1F2E8);

class TanyaSafarMateAiPage extends StatefulWidget {
  const TanyaSafarMateAiPage({super.key});

  @override
  State<TanyaSafarMateAiPage> createState() => _TanyaSafarMateAiPageState();
}

class _TanyaSafarMateAiPageState extends State<TanyaSafarMateAiPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Assalamu’alaikum! Aku SafarMate AI. Antarmuka percakapan ini sudah disiapkan, tetapi layanan AI belum terhubung. Untuk sementara, silakan gunakan menu Tata Cara Umrah dan Doa dan Dzikir.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(
        const _ChatMessage(
          text: 'Pesanmu sudah masuk ke tampilan demo. Jawaban otomatis belum tersedia karena layanan AI belum diintegrasikan. Untuk pertanyaan hukum atau keabsahan ibadah, tanyakan kepada pembimbing ibadah yang kompeten.',
          isUser: false,
        ),
      );
      _controller.clear();
    });
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFFFF5DF),
            child: const Text(
              'Mode demo — belum terhubung ke layanan AI. Jangan masukkan data pribadi atau informasi sensitif.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
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
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        height: 1.45,
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
                    onPressed: _sendMessage,
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
