import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

const String _API = 'http://10.0.2.2:5001';

const _violet = Color(0xFF7B6EF6);
const _indigo = Color(0xFF4F46E5);
const _mint = Color(0xFF34EDB3);
const _rose = Color(0xFFFF5E84);
const _ink = Color(0xFF06060F);
const _surface = Color(0xFF0D0D1C);

class VoiceCallScreen extends StatefulWidget {
  final String? diagnosis;
  const VoiceCallScreen({super.key, this.diagnosis});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isThinking = false;
  bool _muted = false;
  String _spokenText = '';
  String _lastReply = '';

  int _seconds = 0;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<Map<String, String>> _log = [];

  static const String _hinglishPrompt =
      'You are DermAI, a friendly AI skin doctor assistant. '
      'IMPORTANT: Always respond in Hinglish — mix Hindi and English naturally, '
      'like how educated Indians speak in daily life. '
      'Example: "Aapki skin mein acne hai, toh benzoyl peroxide use karo. '
      'Doctor se milna important hai agar 2 weeks mein better nahi hua." '
      'Keep responses short (2-3 sentences max), friendly and conversational. '
      'Never respond in pure English or pure Hindi — always Hinglish.';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initAll();
  }

  Future<void> _initAll() async {
    // ── STT ──────────────────────────────────────────────────────────────
    _sttReady = await _stt.initialize(
      onError: (e) => debugPrint('STT error: $e'),
    );

    // ── TTS — find best available language ───────────────────────────────
    await _tts.awaitSpeakCompletion(true);

    // Check available languages
    final dynamic rawLangs = await _tts.getLanguages;
    final List<String> langs = rawLangs != null
        ? List<String>.from(rawLangs as List)
        : [];
    debugPrint('TTS available langs: $langs');

    // Priority: hi-IN → en-IN → en-US
    if (langs.contains('hi-IN')) {
      await _tts.setLanguage('hi-IN');
      debugPrint('TTS: Using hi-IN');
    } else if (langs.contains('en-IN')) {
      await _tts.setLanguage('en-IN');
      debugPrint('TTS: Using en-IN (fallback)');
    } else {
      await _tts.setLanguage('en-US');
      debugPrint('TTS: Using en-US (final fallback)');
    }

    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    // ✅ YE ADD KARO:
    if (Platform.isAndroid) {
      await _tts.setSharedInstance(true);
    }

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    });

    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      if (mounted) setState(() => _isSpeaking = false);
    });

    // ── Timer ─────────────────────────────────────────────────────────────
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // ── Greeting ──────────────────────────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 800));
    final greeting = widget.diagnosis != null
        ? 'Namaste! Main DermAI hoon. Aapki skin mein ${widget.diagnosis} detect hui hai. Batao, kya problem ho rahi hai?'
        : 'Namaste! Main DermAI hoon — aapka personal skin doctor. Apni problem batao, main help karunga!';
    await _speak(greeting);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }

  // ── STT ───────────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_sttReady || _isListening || _isSpeaking || _muted) return;
    setState(() {
      _isListening = true;
      _spokenText = '';
    });

    // Try hi_IN, fallback to en_IN
    String localeId = 'en_IN';
    final locales = await _stt.locales();
    final hasHindi = locales.any((l) => l.localeId.startsWith('hi'));
    if (hasHindi) localeId = 'hi_IN';

    await _stt.listen(
      onResult: (result) {
        if (mounted) setState(() => _spokenText = result.recognizedWords);
        if (result.finalResult && _spokenText.trim().isNotEmpty) {
          _stopListening();
          _sendToAI(_spokenText.trim());
        }
      },
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      localeId: localeId,
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    if (_muted || !mounted) return;
    try {
      setState(() {
        _isSpeaking = true;
        _lastReply = text;
      });
      await _tts.speak(text); // ✅ stop() hata diya
    } catch (e) {
      debugPrint('Speak error: $e');
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  // ── AI ────────────────────────────────────────────────────────────────────
  Future<void> _sendToAI(String message) async {
    _log.add({'role': 'user', 'text': message});
    if (mounted) setState(() => _isThinking = true);

    try {
      final res = await http
          .post(
            Uri.parse('$_API/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': '$_hinglishPrompt\n\nUser: $message',
              'session_id': 'voice_call_${DateTime.now().day}',
              'diagnosis': widget.diagnosis,
            }),
          )
          .timeout(const Duration(seconds: 20));

      String reply = res.statusCode == 200
          ? (jsonDecode(res.body)['reply'] ??
                'Kuch problem ho gayi, dobara try karo.')
          : 'Server se connect nahi ho paya.';

      // Strip markdown
      reply = reply
          .replaceAll(RegExp(r'\*+'), '')
          .replaceAll(RegExp(r'#+'), '')
          .replaceAll('`', '')
          .trim();

      _log.add({'role': 'bot', 'text': reply});
      if (mounted) setState(() => _isThinking = false);
      await _speak(reply);
    } catch (e) {
      debugPrint('AI error: $e');
      if (mounted) setState(() => _isThinking = false);
      await _speak('Server se connect nahi ho paya. Internet check karo.');
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────
  void _toggleMic() {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      _stopListening();
    } else {
      if (_isSpeaking) {
        _tts.stop();
        if (mounted) setState(() => _isSpeaking = false);
      }
      _startListening();
    }
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _muted = !_muted);
    if (_muted && _isListening) _stopListening();
    if (_muted && _isSpeaking) {
      _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _endCall() {
    HapticFeedback.heavyImpact();
    _stt.cancel();
    _tts.stop();
    _timer?.cancel();
    Navigator.pop(context);
  }

  String get _status {
    if (_isThinking) return 'DermAI soch raha hai...';
    if (_isSpeaking) return 'DermAI bol raha hai...';
    if (_isListening) return 'Sun raha hoon...';
    return 'Mic tap karo aur bolo';
  }

  String get _timerStr {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _activeColor => _isListening ? _mint : _violet;

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCallUI()),
            _buildControls(),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Voice Call',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showLog,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: (_isSpeaking || _isListening) ? _pulseAnim.value : 1.0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isSpeaking || _isListening) ...[
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _activeColor.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _activeColor.withOpacity(0.22),
                        width: 1,
                      ),
                    ),
                  ),
                ],
                Container(
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [_mint, const Color(0xFF00C9A7)]
                          : [_violet, _indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _activeColor.withOpacity(0.5),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),
        const Text(
          'DermAI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _timerStr,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 16,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 20),

        // Status pill
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: _isListening
                ? _mint.withOpacity(0.1)
                : (_isSpeaking || _isThinking)
                ? _violet.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isListening
                  ? _mint.withOpacity(0.3)
                  : (_isSpeaking || _isThinking)
                  ? _violet.withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isListening || _isSpeaking || _isThinking) ...[
                _WaveDots(color: _activeColor),
                const SizedBox(width: 10),
              ],
              Text(
                _status,
                style: TextStyle(
                  color: _isListening
                      ? _mint
                      : (_isSpeaking || _isThinking)
                      ? _violet
                      : Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        if (_spokenText.isNotEmpty)
          _TextBubble(text: '"$_spokenText"', color: _mint),

        if (_lastReply.isNotEmpty && _isSpeaking)
          _TextBubble(
            text: _lastReply.length > 130
                ? '${_lastReply.substring(0, 130)}...'
                : _lastReply,
            color: Colors.white.withOpacity(0.55),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallBtn(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
            label: _muted ? 'Unmute' : 'Mute',
            color: _muted ? _rose : Colors.white.withOpacity(0.6),
            bg: _muted
                ? _rose.withOpacity(0.12)
                : Colors.white.withOpacity(0.07),
            onTap: _toggleMute,
          ),

          GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [_mint, const Color(0xFF00C9A7)]
                      : [_violet, _indigo],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _activeColor.withOpacity(0.5),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),

          _CallBtn(
            icon: Icons.call_end_rounded,
            label: 'End',
            color: Colors.white,
            bg: _rose,
            onTap: _endCall,
            size: 54,
          ),
        ],
      ),
    );
  }

  void _showLog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Baat cheet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _log.isEmpty
                  ? Center(
                      child: Text(
                        'Abhi koi message nahi',
                        style: TextStyle(color: Colors.white.withOpacity(0.3)),
                      ),
                    )
                  : ListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _log.length,
                      itemBuilder: (_, i) {
                        final m = _log[i];
                        final isMe = m['role'] == 'user';
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? _violet.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              m['text'] ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _WaveDots extends StatefulWidget {
  final Color color;
  const _WaveDots({required this.color});

  @override
  State<_WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final phase = (_ctrl.value + i * 0.33) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 4.0 + phase * 10.0,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.5 + phase * 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final String text;
  final Color color;
  const _TextBubble({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  final double size;
  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: Icon(icon, color: color, size: size * 0.44),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
