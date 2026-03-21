import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'result_screen.dart';

const String API_BASE = 'http://10.0.2.2:5001';

class ScanScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onResult;
  const ScanScreen({super.key, required this.onResult});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  late AnimationController _glowCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _dotsCtrl;
  late Animation<double> _glowAnim;

  final List<String> _analyzeMessages = [
    'Reading skin texture...',
    'Running specialist models...',
    'Voting across 3 models...',
    'Generating your report...',
  ];
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _rotateCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  void _cycleMessage() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || !_isAnalyzing) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _analyzeMessages.length);
      _cycleMessage();
    });
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;
      await _analyze(File(picked.path));
    } catch (e) {
      _showError('Could not pick image: $e');
    }
  }

  Future<void> _analyze(File imageFile) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
      _msgIndex = 0;
    });
    _cycleMessage();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final age = prefs.getInt('age_${user?.uid}') ?? 25;
      final gender = prefs.getString('gender_${user?.uid}') ?? 'not provided';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$API_BASE/analyze'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
      request.fields['age'] = age.toString();
      request.fields['sex'] = gender;
      request.fields['uid'] = user?.uid ?? '';

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _isAnalyzing = false;
        });
        widget.onResult(result);
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => ResultScreen(result: result),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      _showError('Analysis failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFFF5E84),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAnalyzing ? _buildAnalyzing() : _buildHome();
  }

  // ── HOME ────────────────────────────────────────────────────────────────
  Widget _buildHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── Hero section ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D0B1E), Color(0xFF06060F)],
              ),
            ),
            child: Column(
              children: [
                // Glowing orb
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7B6EF6,
                          ).withOpacity(_glowAnim.value * 0.6),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating ring
                        AnimatedBuilder(
                          animation: _rotateCtrl,
                          builder: (_, __) => Transform.rotate(
                            angle: _rotateCtrl.value * 2 * pi,
                            child: CustomPaint(
                              size: const Size(130, 130),
                              painter: _RingPainter(),
                            ),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF7B6EF6).withOpacity(0.9),
                                const Color(0xFF4F46E5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.biotech_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scan Your Skin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI-powered diagnosis in seconds',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _ScanButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        isPrimary: true,
                        onTap: () => _pickAndAnalyze(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScanButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        isPrimary: false,
                        onTap: () => _pickAndAnalyze(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats
                Row(
                  children: [
                    _StatTile(
                      value: '95%',
                      label: 'Accuracy',
                      color: const Color(0xFF7B6EF6),
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      value: '3s',
                      label: 'Avg Time',
                      color: const Color(0xFF34EDB3),
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      value: '50+',
                      label: 'Conditions',
                      color: const Color(0xFFFFB547),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Tips
                const Text(
                  'Best shot tips',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _TipRow(
                  icon: Icons.wb_sunny_rounded,
                  text: 'Natural light gives best results',
                  color: const Color(0xFFFFB547),
                ),
                _TipRow(
                  icon: Icons.center_focus_strong_rounded,
                  text: 'Hold steady — no blur',
                  color: const Color(0xFF34EDB3),
                ),
                _TipRow(
                  icon: Icons.crop_free_rounded,
                  text: 'Fill the frame with affected area',
                  color: const Color(0xFF7B6EF6),
                ),
                _TipRow(
                  icon: Icons.no_flash_rounded,
                  text: 'Avoid harsh flash',
                  color: const Color(0xFFFF5E84),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ANALYZING ───────────────────────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Container(
      color: const Color(0xFF06060F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing scanner orb
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 160 + (_glowAnim.value * 20),
                    height: 160 + (_glowAnim.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(
                          0xFF7B6EF6,
                        ).withOpacity(_glowAnim.value * 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF7B6EF6).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Rotating ring
                  AnimatedBuilder(
                    animation: _rotateCtrl,
                    builder: (_, __) => Transform.rotate(
                      angle: _rotateCtrl.value * 2 * pi,
                      child: CustomPaint(
                        size: const Size(130, 130),
                        painter: _RingPainter(glowIntensity: _glowAnim.value),
                      ),
                    ),
                  ),
                  // Core
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B6EF6), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF7B6EF6,
                          ).withOpacity(_glowAnim.value * 0.7),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.biotech_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'Analyzing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Cycling message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _analyzeMessages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Thin progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7B6EF6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom ring painter ───────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double glowIntensity;
  _RingPainter({this.glowIntensity = 0.7});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF7B6EF6).withOpacity(glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.glowIntensity != glowIntensity;
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────
class _ScanButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ScanButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF7B6EF6), Color(0xFF4F46E5)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B6EF6).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TipRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
