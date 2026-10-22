import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/quiz_service.dart';
import '../utils/format_utils.dart';

const Color _green = Color(0xFF176B50);
const Color _lightGreen = Color(0xFFE1F2E8);

enum _Phase { menu, playing, result }

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final QuizService _service = QuizService();

  _Phase _phase = _Phase.menu;
  QuizCategory _category = QuizCategory.campuran;

  List<QuizQuestion> _questions = [];
  int _index = 0;
  int _correct = 0;
  int? _selected;
  DateTime? _startedAt;
  int _durationSeconds = 0;

  bool _isSaving = false;
  String? _saveError;
  late Future<List<QuizHistoryEntry>> _historyFuture;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sensorAvailable = true;

  static const double _shakeThresholdG = 2.7;
  static const Duration _shakeCooldown = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _historyFuture = _service.fetchHistory();
    _listenShake();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _listenShake() {
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (event) {
              final g =
                  sqrt(
                    event.x * event.x + event.y * event.y + event.z * event.z,
                  ) /
                  9.80665;
              if (g < _shakeThresholdG) return;

              final now = DateTime.now();
              if (now.difference(_lastShake) < _shakeCooldown) return;
              _lastShake = now;

              if (mounted) _onShake();
            },
            onError: (_) {
              if (mounted) setState(() => _sensorAvailable = false);
            },
          );
    } catch (_) {
      _sensorAvailable = false;
    }
  }

  bool get _shakeAllowed {
    switch (_phase) {
      case _Phase.menu:
      case _Phase.result:
        return true;
      case _Phase.playing:
        return _index == 0 && _selected == null;
    }
  }

  void _onShake() {
    if (!_shakeAllowed) return;
    HapticFeedback.mediumImpact();
    _startQuiz(_category);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Soal diacak! 🎲'),
          duration: Duration(seconds: 1),
        ),
      );
  }

  void _startQuiz(QuizCategory category) {
    setState(() {
      _category = category;
      _questions = QuizService.generateRound(category);
      _index = 0;
      _correct = 0;
      _selected = null;
      _startedAt = DateTime.now();
      _saveError = null;
      _phase = _Phase.playing;
    });
  }

  void _answer(int option) {
    if (_selected != null) return;
    setState(() {
      _selected = option;
      if (option == _questions[_index].correctIndex) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
      return;
    }

    _durationSeconds = DateTime.now().difference(_startedAt!).inSeconds;
    setState(() => _phase = _Phase.result);
    await _saveResult();
  }

  Future<void> _saveResult() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await _service.saveResult(
        category: _category,
        correctCount: _correct,
        totalQuestions: _questions.length,
        durationSeconds: _durationSeconds,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _historyFuture = _service.fetchHistory();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Hasil belum tersimpan: $e';
      });
    }
  }

  Future<bool> _confirmExit() async {
    if (_phase != _Phase.playing) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari kuis?'),
        content: const Text('Progres kuis ini tidak akan disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut main'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.playing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Kuis Manasik & Destinasi')),
        body: switch (_phase) {
          _Phase.menu => _buildMenu(),
          _Phase.playing => _buildPlaying(),
          _Phase.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildMenu() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF176B50), Color(0xFF399477)],
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.quiz_rounded, color: Colors.white, size: 36),
              SizedBox(height: 12),
              Text(
                'Uji pengetahuanmu!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '5 soal acak tiap ronde. Pilih kategori untuk mulai.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _shakeHint(),
        const SizedBox(height: 12),
        for (final c in QuizCategory.values)
          Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _lightGreen,
                child: Icon(_categoryIcon(c), color: _green),
              ),
              title: Text(
                c.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(c.description),
              trailing: const Icon(Icons.play_arrow_rounded, color: _green),
              onTap: () => _startQuiz(c),
            ),
          ),
        const SizedBox(height: 12),
        _historySection(),
      ],
    );
  }

  Widget _shakeHint() {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF4D8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.vibration_rounded, color: Colors.brown),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _sensorAvailable
                    ? 'Goyangkan HP untuk mengacak soal dan langsung memulai '
                          'ronde baru.'
                    : 'Sensor goyang tidak tersedia di perangkat ini. '
                          'Gunakan tombol Acak.',
                style: const TextStyle(height: 1.4, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    return FutureBuilder<List<QuizHistoryEntry>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Riwayat kuis belum bisa dimuat (pastikan tabel quiz_results '
              'sudah dibuat).',
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          );
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) return const SizedBox.shrink();

        final best = history.map((e) => e.score).reduce(max);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Text(
                    'Riwayat terakhir',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _green,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Skor terbaik: $best',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            for (final h in history.take(5))
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    h.score >= 80
                        ? Icons.emoji_events_rounded
                        : Icons.history_rounded,
                    color: h.score >= 80 ? Colors.amber.shade700 : _green,
                  ),
                  title: Text(
                    '${_categoryLabel(h.category)} • '
                    '${h.correctCount}/${h.totalQuestions} benar',
                  ),
                  subtitle: Text(
                    '${formatDateShort(h.createdAt)} '
                    '${formatHm(h.createdAt.hour, h.createdAt.minute)} • '
                    '${h.durationSeconds} detik',
                  ),
                  trailing: Text(
                    '${h.score}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _green,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlaying() {
    final q = _questions[_index];
    final answered = _selected != null;
    final isLast = _index == _questions.length - 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Soal ${_index + 1} dari ${_questions.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _green,
              ),
            ),
            const Spacer(),
            Chip(
              avatar: const Icon(Icons.check_circle, size: 16, color: _green),
              label: Text('$_correct benar'),
              visualDensity: VisualDensity.compact,
              backgroundColor: _lightGreen,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_index + (answered ? 1 : 0)) / _questions.length,
            minHeight: 8,
            backgroundColor: _lightGreen,
            color: _green,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.category.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.question,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < q.options.length; i++) _optionTile(q, i),
        if (answered) ...[
          const SizedBox(height: 4),
          Card(
            elevation: 0,
            color: _selected == q.correctIndex
                ? _lightGreen
                : const Color(0xFFFDECEA),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected == q.correctIndex ? 'Benar! 🎉' : 'Kurang tepat',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(q.explanation, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _next,
            child: Text(isLast ? 'Lihat Hasil' : 'Soal Berikutnya'),
          ),
        ] else if (_index == 0) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _onShake,
              icon: const Icon(Icons.shuffle_rounded),
              label: Text(
                _sensorAvailable
                    ? 'Acak soal (atau goyangkan HP)'
                    : 'Acak soal',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _optionTile(QuizQuestion q, int i) {
    final answered = _selected != null;
    final isCorrect = i == q.correctIndex;
    final isChosen = i == _selected;

    Color border = Colors.grey.shade300;
    Color background = Colors.white;
    IconData? trailing;
    Color? trailingColor;

    if (answered) {
      if (isCorrect) {
        border = _green;
        background = _lightGreen;
        trailing = Icons.check_circle;
        trailingColor = _green;
      } else if (isChosen) {
        border = Colors.red.shade400;
        background = const Color(0xFFFDECEA);
        trailing = Icons.cancel;
        trailingColor = Colors.red.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: answered ? null : () => _answer(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: _lightGreen,
                  child: Text(
                    String.fromCharCode(65 + i),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(q.options[i])),
                if (trailing != null) Icon(trailing, color: trailingColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final total = _questions.length;
    final score = total == 0 ? 0 : ((_correct / total) * 100).round();

    final String message;
    final IconData icon;
    if (score >= 80) {
      message = 'Masya Allah, pengetahuanmu sudah sangat baik!';
      icon = Icons.emoji_events_rounded;
    } else if (score >= 60) {
      message = 'Bagus! Sedikit lagi belajar, kamu pasti lebih siap.';
      icon = Icons.thumb_up_alt_rounded;
    } else {
      message = 'Yuk pelajari lagi menu Panduan, lalu coba kembali.';
      icon = Icons.menu_book_rounded;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Icon(icon, size: 72, color: Colors.amber.shade700),
        const SizedBox(height: 12),
        Text(
          '$score',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: _green,
          ),
        ),
        Text(
          '$_correct dari $total soal benar • $_durationSeconds detik',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (_isSaving)
          const Center(
            child: Text('Menyimpan hasil…', style: TextStyle(fontSize: 12)),
          ),
        if (_saveError != null)
          Card(
            elevation: 0,
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    _saveError!,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _saveResult,
                    child: const Text('Coba simpan lagi'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _startQuiz(_category),
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Main Lagi (soal diacak)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _isSaving
              ? null
              : () => setState(() => _phase = _Phase.menu),
          child: const Text('Kembali ke Menu'),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Tip: goyangkan HP untuk langsung main lagi',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(QuizCategory c) {
    switch (c) {
      case QuizCategory.manasik:
        return Icons.mosque_rounded;
      case QuizCategory.destinasi:
        return Icons.travel_explore_rounded;
      case QuizCategory.campuran:
        return Icons.shuffle_rounded;
    }
  }

  String _categoryLabel(String id) {
    return QuizCategory.values
        .firstWhere((c) => c.id == id, orElse: () => QuizCategory.campuran)
        .label;
  }
}
