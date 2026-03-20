import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // User data
  final _nameController = TextEditingController();
  int _selectedAge = 25;
  String _selectedGender = '';

  late AnimationController _animController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _requestLocationAndFinish() async {
    await Permission.location.request();
    await _saveAndContinue();
  }

  Future<void> _saveAndContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name_${user.uid}', _nameController.text);
    await prefs.setInt('age_${user.uid}', _selectedAge);
    await prefs.setString('gender_${user.uid}', _selectedGender);
    await prefs.setBool('onboarded_${user.uid}', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildNamePage(),
                  _buildAgePage(),
                  _buildGenderPage(),
                  _buildLocationPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAGE 1: NAME ──
  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildEmoji('👋'),
          const SizedBox(height: 24),
          const Text(
            "What's your\nname?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll personalize your experience',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Your name...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 24,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildNextButton(
            onTap: () {
              if (_nameController.text.trim().isNotEmpty) _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ── PAGE 2: AGE ──
  Widget _buildAgePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildEmoji('🎂'),
          const SizedBox(height: 24),
          const Text(
            "How old\nare you?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Helps us give age-appropriate advice',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 48),

          // Age display
          Center(
            child: Text(
              '$_selectedAge',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'years old',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Scroll picker
          SizedBox(
            height: 160,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 50,
              perspective: 0.003,
              diameterRatio: 1.8,
              physics: const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(
                initialItem: _selectedAge - 1,
              ),
              onSelectedItemChanged: (i) =>
                  setState(() => _selectedAge = i + 1),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 100,
                builder: (ctx, i) {
                  final age = i + 1;
                  final isSelected = age == _selectedAge;
                  return Center(
                    child: Text(
                      '$age',
                      style: TextStyle(
                        fontSize: isSelected ? 24 : 18,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 40),
          _buildNextButton(onTap: _nextPage),
        ],
      ),
    );
  }

  // ── PAGE 3: GENDER ──
  Widget _buildGenderPage() {
    final genders = [
      {'label': 'Male', 'emoji': '👨', 'value': 'male'},
      {'label': 'Female', 'emoji': '👩', 'value': 'female'},
      {'label': 'Other', 'emoji': '🧑', 'value': 'other'},
    ];

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildEmoji('🧬'),
          const SizedBox(height: 24),
          const Text(
            "What's your\ngender?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Helps with accurate skin analysis',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 48),

          ...genders.map((g) {
            final isSelected = _selectedGender == g['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedGender = g['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6C63FF).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Text(g['emoji']!, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Text(
                      g['label']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF6C63FF),
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 40),
          _buildNextButton(
            onTap: () {
              if (_selectedGender.isNotEmpty) _nextPage();
            },
          ),
        ],
      ),
    );
  }

  // ── PAGE 4: LOCATION ──
  Widget _buildLocationPage() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildEmoji('📍'),
          const SizedBox(height: 24),
          const Text(
            "Find nearby\ndermatologists?",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll help you find the best doctors near you',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 40),

          // Location card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF6C63FF),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enable Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To show nearby dermatologists\nand clinics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Allow button
          GestureDetector(
            onTap: _requestLocationAndFinish,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Allow Location Access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Skip button
          GestureDetector(
            onTap: _saveAndContinue,
            child: Center(
              child: Text(
                'Skip for now',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.3),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmoji(String emoji) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
    );
  }

  Widget _buildNextButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
