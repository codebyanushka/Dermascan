import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String _API = 'http://10.0.2.2:5001';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Save user to backend DB so FK constraint never fires ──────────────
  Future<void> _saveUserToBackend(User user, SharedPreferences prefs) async {
    try {
      await http
          .post(
            Uri.parse('$_API/save-user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': user.uid,
              'name':
                  prefs.getString('name_${user.uid}') ?? user.displayName ?? '',
              'email': user.email ?? '',
              'age': prefs.getInt('age_${user.uid}') ?? 0,
              'gender': prefs.getString('gender_${user.uid}') ?? '',
              'skin_type': '',
              'location': '',
              'onboarded': prefs.getBool('onboarded_${user.uid}') ?? false,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-fatal — app still works, DB just won't have record yet
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCred.user;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      // ✅ Always save/upsert user in DB — prevents FK constraint error
      await _saveUserToBackend(user, prefs);

      final onboarded = prefs.getBool('onboarded_${user.uid}') ?? false;

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        onboarded ? '/home' : '/onboarding',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: const Color(0xFFFF5E84),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060F),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0B1E), Color(0xFF06060F)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo ──────────────────────────────────────────
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF7B6EF6).withOpacity(0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B6EF6), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B6EF6).withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.biotech_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'DermaCam',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'AI-powered skin analysis\nin your pocket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.45),
                      height: 1.6,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Feature rows ──────────────────────────────────
                  _FeatureRow(
                    icon: Icons.speed_rounded,
                    text: '3-second AI diagnosis',
                    color: const Color(0xFF7B6EF6),
                  ),
                  const SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.psychology_rounded,
                    text: '7 specialized models voting',
                    color: const Color(0xFF34EDB3),
                  ),
                  const SizedBox(height: 12),
                  _FeatureRow(
                    icon: Icons.lock_rounded,
                    text: 'Private & secure',
                    color: const Color(0xFFFFB547),
                  ),

                  const Spacer(flex: 2),

                  // ── Google Sign In ────────────────────────────────
                  _isLoading
                      ? const SizedBox(
                          height: 56,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF7B6EF6),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _signInWithGoogle,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 28,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0D0B1E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),

                  Text(
                    'By continuing you agree to our Terms & Privacy Policy.\nThis app provides AI screening, not medical advice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.25),
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
