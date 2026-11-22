import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class _Lang {
  final String code;
  final String name;
  final TranslateLanguage mlLang;
  final String ttsLocale;
  final bool rtl;

  const _Lang(
    this.code,
    this.name,
    this.mlLang,
    this.ttsLocale, {
    this.rtl = false,
  });
}

class _HistoryItem {
  final String source;
  final String translated;
  final _Lang lang;

  const _HistoryItem(this.source, this.translated, this.lang);
}

class PenerjemahSuaraPage extends StatefulWidget {
  const PenerjemahSuaraPage({super.key});

  @override
  State<PenerjemahSuaraPage> createState() => _PenerjemahSuaraPageState();
}

class _PenerjemahSuaraPageState extends State<PenerjemahSuaraPage>
    with WidgetsBindingObserver {
  static const Color safarGreen = Color(0xFF176B50);
  static const Color safarLightGreen = Color(0xFFE1F2E8);
  static const Color pageBackground = Color(0xFFF7F8F6);

  static const List<_Lang> _languages = [
    _Lang('ar', 'Bahasa Arab', TranslateLanguage.arabic, 'ar-SA', rtl: true),
    _Lang('en', 'Bahasa Inggris', TranslateLanguage.english, 'en-US'),
    _Lang('ur', 'Bahasa Urdu', TranslateLanguage.urdu, 'ur-PK', rtl: true),
    _Lang('tr', 'Bahasa Turki', TranslateLanguage.turkish, 'tr-TR'),
    _Lang('ms', 'Bahasa Melayu', TranslateLanguage.malay, 'ms-MY'),
  ];

  static const List<String> _quickPhrases = [
    'Di mana toilet terdekat?',
    'Di mana arah kiblat?',
    'Tolong, saya tersesat.',
    'Berapa harga ini?',
    'Di mana pintu masuk masjid?',
    'Saya butuh bantuan medis.',
    'Di mana hotel saya?',
    'Terima kasih banyak.',
  ];

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _inputController = TextEditingController();
  final ValueNotifier<double> _soundLevel = ValueNotifier<double>(0);
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  OnDeviceTranslator? _translator;
  String? _translatorTargetCode;

  final List<_HistoryItem> _history = [];

  String _translatedText = '';
  String _statusMessage = 'Tekan tombol mikrofon untuk mulai berbicara.';
  String _speechLocaleId = 'id_ID';

  // Untuk mencegah terjemahan ganda / hasil basi.
  int _translationToken = 0;
  String _lastSource = '';
  String _lastTargetCode = '';

  _Lang _target = _languages.first;

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isTranslating = false;
  bool _isSpeaking = false;

  String get _recognizedText => _inputController.text;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    _initializeTts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hentikan mikrofon dan suara ketika aplikasi masuk latar belakang.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _speech.cancel();
      _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _isSpeaking = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Inisialisasi
  // ---------------------------------------------------------------------------

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if ((status == 'notListening' || status == 'done') && _isListening) {
            setState(() => _isListening = false);
            _soundLevel.value = 0;
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _statusMessage = _friendlySpeechError(error.errorMsg);
          });
          _soundLevel.value = 0;
        },
      );

      if (available) {
        await _pickIndonesianLocale();
      }

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
        _statusMessage = available
            ? 'Siap. Tekan mikrofon dan ucapkan kalimat dalam bahasa Indonesia.'
            : 'Pengenalan suara tidak tersedia. Pastikan izin mikrofon aktif, atau ketik kalimat secara manual.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _statusMessage = 'Gagal menyiapkan mikrofon. Periksa izin perangkat, atau ketik kalimat secara manual.';
      });
    }
  }

  Future<void> _pickIndonesianLocale() async {
    try {
      final locales = await _speech.locales();
      String? exact;
      String? partial;
      for (final l in locales) {
        final id = l.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'id_id') exact = l.localeId;
        if (id.startsWith('id') && partial == null) partial = l.localeId;
      }
      _speechLocaleId = exact ?? partial ?? 'id_ID';
    } catch (_) {
      _speechLocaleId = 'id_ID';
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSpeechRate(0.45);

      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _flutterTts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _flutterTts.setErrorHandler((message) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _statusMessage = 'Suara tidak dapat diputar.';
          });
        }
      });
    } catch (_) {
      // Abaikan; kesalahan akan ditangani saat memutar suara.
    }
  }

  String _friendlySpeechError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('permission')) {
      return 'Izin mikrofon ditolak. Aktifkan izin mikrofon di Pengaturan perangkat.';
    }
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      return 'Suara tidak terdengar jelas. Coba bicara lebih dekat dan ulangi.';
    }
    if (msg.contains('network')) {
      return 'Pengenalan suara membutuhkan koneksi internet pada perangkat ini.';
    }
    return 'Pengenalan suara mengalami kendala: $raw';
  }

  // ---------------------------------------------------------------------------
  // Mendengarkan
  // ---------------------------------------------------------------------------

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initializeSpeech();
      if (!_speechAvailable) return;
    }

    HapticFeedback.lightImpact();
    await _flutterTts.stop();

    if (!mounted) return;

    _translationToken++;
    _inputController.clear();

    setState(() {
      _translatedText = '';
      _isListening = true;
      _isSpeaking = false;
      _isTranslating = false;
      _statusMessage = 'Sedang mendengarkan...';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        _inputController.value = TextEditingValue(
          text: result.recognizedWords,
          selection: TextSelection.collapsed(
            offset: result.recognizedWords.length,
          ),
        );

        setState(() {
          _statusMessage = result.finalResult
              ? 'Ucapan berhasil dikenali.'
              : 'Mendengarkan ucapan...';
        });

        if (result.finalResult && _recognizedText.trim().isNotEmpty) {
          _translateText();
        }
      },
      onSoundLevelChange: (level) {
        // Normalisasi kasar ke 0..1 untuk animasi mikrofon.
        _soundLevel.value = ((level + 2) / 12).clamp(0.0, 1.0);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _speechLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> _stopListening() async {
    HapticFeedback.lightImpact();
    await _speech.stop();
    _soundLevel.value = 0;

    if (!mounted) return;

    setState(() {
      _isListening = false;
      _statusMessage = _recognizedText.trim().isEmpty
          ? 'Belum ada ucapan yang dikenali. Coba bicara kembali.'
          : 'Ucapan berhasil direkam.';
    });

    // Duplikasi dengan hasil final dicegah oleh pengecekan di _translateText.
    if (_recognizedText.trim().isNotEmpty) {
      await _translateText();
    }
  }

  // ---------------------------------------------------------------------------
  // Terjemahan
  // ---------------------------------------------------------------------------

  Future<void> _ensureModel(TranslateLanguage lang, String name) async {
    final downloaded = await _modelManager.isModelDownloaded(lang.bcpCode);
    if (downloaded) return;

    if (mounted) {
      setState(
        () => _statusMessage =
            'Mengunduh model $name (hanya sekali, butuh internet)...',
      );
    }

    final ok = await _modelManager.downloadModel(
      lang.bcpCode,
      isWifiRequired: false,
    );
    if (!ok) throw Exception('Model $name gagal diunduh');
  }

  OnDeviceTranslator _getTranslator() {
    if (_translator != null && _translatorTargetCode == _target.code) {
      return _translator!;
    }
    _translator?.close();
    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.indonesian,
      targetLanguage: _target.mlLang,
    );
    _translatorTargetCode = _target.code;
    return _translator!;
  }

  Future<void> _translateText({bool force = false}) async {
    final text = _recognizedText.trim();
    if (text.isEmpty) return;

    // Lewati bila teks & bahasa sama dan hasilnya sudah ada.
    if (!force &&
        text == _lastSource &&
        _target.code == _lastTargetCode &&
        _translatedText.isNotEmpty) {
      return;
    }

    final token = ++_translationToken;
    final target = _target;

    setState(() {
      _isTranslating = true;
      _statusMessage = 'Sedang menerjemahkan ke ${target.name}...';
    });

    try {
      await _ensureModel(TranslateLanguage.indonesian, 'Bahasa Indonesia');
      await _ensureModel(target.mlLang, target.name);

      final translated = await _getTranslator().translateText(text);

      // Abaikan hasil bila sudah ada permintaan yang lebih baru.
      if (!mounted || token != _translationToken) return;

      _lastSource = text;
      _lastTargetCode = target.code;

      setState(() {
        _translatedText = translated;
        _statusMessage = 'Terjemahan selesai.';
        _history.removeWhere(
          (h) => h.source == text && h.lang.code == target.code,
        );
        _history.insert(0, _HistoryItem(text, translated, target));
        if (_history.length > 8) _history.removeLast();
      });
    } catch (_) {
      if (!mounted || token != _translationToken) return;
      setState(() {
        _statusMessage = 'Terjemahan gagal. Model bahasa mungkin belum terunduh — periksa koneksi internet lalu coba lagi.';
      });
    } finally {
      if (mounted && token == _translationToken) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _changeTargetLanguage(String? code) async {
    if (code == null || code == _target.code) return;

    await _flutterTts.stop();
    if (!mounted) return;

    _translationToken++;

    setState(() {
      _target = _languages.firstWhere((l) => l.code == code);
      _translatedText = '';
      _isSpeaking = false;
      _isTranslating = false;
    });

    if (_recognizedText.trim().isNotEmpty) {
      await _translateText(force: true);
    }
  }

  Future<void> _useQuickPhrase(String phrase) async {
    if (_isListening) await _speech.cancel();
    await _flutterTts.stop();
    if (!mounted) return;

    _inputController.value = TextEditingValue(
      text: phrase,
      selection: TextSelection.collapsed(offset: phrase.length),
    );
    setState(() {
      _isListening = false;
      _translatedText = '';
    });
    await _translateText(force: true);
  }

  void _loadHistory(_HistoryItem item) {
    _inputController.text = item.source;
    final lang = item.lang;
    setState(() {
      _target = lang;
      _translatedText = item.translated;
      _lastSource = item.source;
      _lastTargetCode = lang.code;
      _statusMessage = 'Riwayat dimuat.';
    });
  }

  // ---------------------------------------------------------------------------
  // Suara keluaran, salin, hapus
  // ---------------------------------------------------------------------------

  Future<void> _speakTranslation() async {
    final text = _translatedText.trim();
    if (text.isEmpty) return;

    try {
      await _flutterTts.stop();

      final available = await _flutterTts.isLanguageAvailable(
        _target.ttsLocale,
      );
      if (available != true && available != 1) {
        if (!mounted) return;
        setState(
          () => _statusMessage =
              'Suara ${_target.name} belum tersedia di perangkat. Instal data suara pada Pengaturan > Text-to-speech.',
        );
        return;
      }

      await _flutterTts.setLanguage(_target.ttsLocale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.speak(text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _statusMessage = 'Suara tidak dapat diputar. Periksa dukungan bahasa pada perangkat.';
      });
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _copyTranslation() async {
    if (_translatedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _translatedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Terjemahan disalin.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _clearTranslation() async {
    _translationToken++;
    await _speech.cancel();
    await _flutterTts.stop();

    if (!mounted) return;

    _inputController.clear();
    _soundLevel.value = 0;
    _lastSource = '';

    setState(() {
      _translatedText = '';
      _isListening = false;
      _isTranslating = false;
      _isSpeaking = false;
      _statusMessage = 'Tekan tombol mikrofon untuk mulai berbicara.';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.cancel();
    _flutterTts.stop();
    _translator?.close();
    _inputController.dispose();
    _soundLevel.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: safarGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Penerjemah Suara',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntroCard(),
                const SizedBox(height: 20),
                _buildLanguageSelector(),
                const SizedBox(height: 16),
                _buildSpeechInputCard(),
                const SizedBox(height: 16),
                _buildTranslationCard(),
                const SizedBox(height: 16),
                _buildQuickPhrases(),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildHistory(),
                ],
                const SizedBox(height: 18),
                _buildStatusMessage(),
                const SizedBox(height: 16),
                _buildClearButton(),
                const SizedBox(height: 14),
                const Text(
                  'Catatan: Penggunaan pertama kali mungkin memerlukan koneksi internet untuk mengunduh model bahasa. Setelah terunduh, terjemahan dapat digunakan tanpa internet. Ketersediaan pengenalan suara dan suara keluaran bergantung pada layanan bahasa di perangkat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: safarLightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(Icons.translate_rounded, color: safarGreen, size: 25),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Berkomunikasi lebih mudah',
                  style: TextStyle(
                    color: safarGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Ucapkan atau ketik kalimat dalam bahasa Indonesia, lalu lihat dan dengarkan hasil terjemahannya untuk membantu berkomunikasi selama perjalanan ibadah.',
                  style: TextStyle(
                    color: Color(0xFF38584B),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAE6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _languageLabel(
              title: 'Dari',
              language: 'Bahasa Indonesia',
              icon: Icons.record_voice_over_outlined,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, color: safarGreen),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terjemahkan ke',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 5),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _target.code,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: safarGreen,
                    ),
                    style: const TextStyle(
                      color: safarGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      for (final l in _languages)
                        DropdownMenuItem(value: l.code, child: Text(l.name)),
                    ],
                    onChanged: _isListening || _isTranslating
                        ? null
                        : _changeTargetLanguage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageLabel({
    required String title,
    required String language,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(icon, color: safarGreen, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                language,
                style: const TextStyle(
                  color: safarGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeechInputCard() {
    final hasText = _recognizedText.trim().isNotEmpty;

    return _contentCard(
      title: 'Ucapkan atau ketik kalimat',
      subtitle: 'Bahasa Indonesia',
      icon: Icons.mic_none_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: pageBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _inputController,
              readOnly: _isListening,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _translateText(),
              style: const TextStyle(
                color: Color(0xFF26352E),
                fontSize: 14,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText:
                    'Hasil suara akan muncul di sini, atau ketik manual...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isListening)
            FilledButton.icon(
              onPressed: hasText && !_isTranslating
                  ? () => _translateText(force: true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: safarGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: const Icon(Icons.translate_rounded, size: 18),
              label: const Text('Terjemahkan'),
            ),
          const SizedBox(height: 16),
          Center(child: _buildMicButton()),
          const SizedBox(height: 9),
          Text(
            _isListening
                ? 'Ketuk untuk berhenti'
                : 'Ketuk mikrofon untuk berbicara',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: safarGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_speechAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Layanan pengenalan suara belum tersedia atau belum diizinkan. Anda tetap bisa mengetik kalimat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.deepOrange, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return ValueListenableBuilder<double>(
      valueListenable: _soundLevel,
      builder: (context, level, _) {
        final glow = _isListening ? 4 + level * 18 : 0.0;
        return Semantics(
          button: true,
          label: _isListening ? 'Hentikan perekaman' : 'Mulai berbicara',
          child: GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _isListening ? Colors.red.shade50 : safarLightGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening ? Colors.red : safarGreen,
                  width: 1.5,
                ),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.22),
                          blurRadius: glow,
                          spreadRadius: glow / 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.red : safarGreen,
                size: 31,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranslationCard() {
    final hasResult = _translatedText.isNotEmpty;

    return _contentCard(
      title: 'Hasil terjemahan',
      subtitle: _target.name,
      icon: Icons.g_translate_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 105),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: safarLightGreen.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isTranslating
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        color: safarGreen,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : SelectableText(
                    hasResult
                        ? _translatedText
                        : 'Hasil terjemahan akan muncul di sini...',
                    textAlign: hasResult && _target.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    textDirection: hasResult && _target.rtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: TextStyle(
                      color: hasResult ? safarGreen : Colors.black38,
                      fontSize: hasResult && _target.rtl ? 20 : 16,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !hasResult || _isTranslating
                      ? null
                      : (_isSpeaking ? _stopSpeaking : _speakTranslation),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: safarGreen,
                    side: const BorderSide(color: safarGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: Icon(
                    _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _isSpeaking ? 'Hentikan suara' : 'Dengarkan terjemahan',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Salin terjemahan',
                onPressed: hasResult && !_isTranslating
                    ? _copyTranslation
                    : null,
                style: IconButton.styleFrom(
                  foregroundColor: safarGreen,
                  side: const BorderSide(color: safarGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhrases() {
    return _contentCard(
      title: 'Kalimat cepat',
      subtitle: 'Ketuk untuk menerjemahkan',
      icon: Icons.bolt_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final phrase in _quickPhrases)
            ActionChip(
              label: Text(phrase),
              labelStyle: const TextStyle(color: safarGreen, fontSize: 12),
              backgroundColor: safarLightGreen,
              side: BorderSide.none,
              onPressed: _isTranslating ? null : () => _useQuickPhrase(phrase),
            ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return _contentCard(
      title: 'Riwayat terjemahan',
      subtitle: '${_history.length} terakhir',
      icon: Icons.history_rounded,
      child: Column(
        children: [
          for (final item in _history)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _loadHistory(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF26352E),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.translated,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: item.lang.rtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: const TextStyle(
                              color: safarGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.lang.name.replaceFirst('Bahasa ', ''),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8ECE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: safarGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF26352E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: safarGreen, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClearButton() {
    final empty = _recognizedText.isEmpty && _translatedText.isEmpty;
    return TextButton.icon(
      onPressed: empty ? null : _clearTranslation,
      style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Hapus dan mulai ulang'),
    );
  }
}
