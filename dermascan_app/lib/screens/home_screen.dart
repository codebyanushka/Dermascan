import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_screen.dart';
import 'skincare_tab.dart';
import 'chatbot_tab.dart';
import 'history_screen.dart';
import 'reminders_screen.dart';

const _ink = Color(0xFF06060F);
const _surface = Color(0xFF0D0D1C);
const _card = Color(0xFF111127);
const _violet = Color(0xFF7B6EF6);
const _indigo = Color(0xFF4F46E5);
const _mint = Color(0xFF34EDB3);
const _rose = Color(0xFFFF5E84);
const _amber = Color(0xFFFFB547);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  String _userName = '';
  String _userEmail = '';
  String? _photoUrl;
  int _userAge = 25;
  String _userGender = '';
  Map<String, dynamic>? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName =
          prefs.getString('name_${user.uid}') ??
          user.displayName?.split(' ').first ??
          'User';
      _userEmail = user.email ?? '';
      _photoUrl = user.photoURL;
      _userAge = prefs.getInt('age_${user.uid}') ?? 25;
      _userGender = prefs.getString('gender_${user.uid}') ?? '';
    });
  }

  void _openProfile() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(
        userName: _userName,
        userEmail: _userEmail,
        photoUrl: _photoUrl,
        userAge: _userAge,
        userGender: _userGender,
        onEdit: () {
          Navigator.pop(context);
          _openEditProfile();
        },
        onSwitch: () async {
          Navigator.pop(context);
          await FirebaseAuth.instance.signOut();
          if (mounted)
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (_) => false);
        },
        onLogout: () {
          Navigator.pop(context);
          _confirmLogout();
        },
      ),
    );
  }

  void _openEditProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        initName: _userName,
        initAge: _userAge,
        initGender: _userGender,
        onSave: (name, age, gender) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name_${user.uid}', name);
          await prefs.setInt('age_${user.uid}', age);
          await prefs.setString('gender_${user.uid}', gender);
          setState(() {
            _userName = name;
            _userAge = age;
            _userGender = gender;
          });
        },
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => _LogoutDialog(
        onConfirm: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted)
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (_) => false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ScanScreen(
        onResult: (r) => setState(() {
          _lastResult = r;
          _currentTab = 0;
        }),
      ),
      SkincareTab(diagnosis: _lastResult?['diagnosis']),
      ChatbotTab(diagnosis: _lastResult?['diagnosis']),
      const HistoryScreen(),
      const RemindersScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _ink,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: tabs[_currentTab],
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _ink.withOpacity(0.75),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_violet, _mint],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _violet.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.biotech_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'DermaCam',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'AI Dermatologist',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openProfile,
                      child: Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_violet, _indigo],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _violet.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _photoUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _userName.isNotEmpty
                                          ? _userName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: _mint,
                                shape: BoxShape.circle,
                                border: Border.all(color: _ink, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNav() {
    final items = [
      _NavItem(icon: Icons.biotech_rounded, label: 'Scan', color: _violet),
      _NavItem(icon: Icons.spa_rounded, label: 'Skin Care', color: _mint),
      _NavItem(icon: Icons.smart_toy_rounded, label: 'DermAI', color: _rose),
      _NavItem(icon: Icons.history_rounded, label: 'History', color: _amber),
      _NavItem(
        icon: Icons.alarm_rounded,
        label: 'Reminders',
        color: const Color(0xFFFF9ECD),
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final sel = _currentTab == i;
                  final item = items[i];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: sel ? 12 : 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? item.color.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: sel
                            ? Border.all(
                                color: item.color.withOpacity(0.25),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: sel
                                ? item.color
                                : Colors.white.withOpacity(0.25),
                          ),
                          if (sel) ...[
                            const SizedBox(width: 5),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  _NavItem({required this.icon, required this.label, required this.color});
}

// ═══════════════════════════════════════════════════
// PROFILE SHEET
// ═══════════════════════════════════════════════════
class _ProfileSheet extends StatelessWidget {
  final String userName, userEmail;
  final String? photoUrl;
  final int userAge;
  final String userGender;
  final VoidCallback onEdit, onSwitch, onLogout;

  const _ProfileSheet({
    required this.userName,
    required this.userEmail,
    required this.photoUrl,
    required this.userAge,
    required this.userGender,
    required this.onEdit,
    required this.onSwitch,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final genderEmoji =
        {'male': '👨', 'female': '👩', 'other': '🧑'}[userGender] ?? '🧑';
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_violet.withOpacity(0.15), _mint.withOpacity(0.07)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _violet.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_violet, _indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _violet.withOpacity(0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: photoUrl != null
                      ? ClipOval(
                          child: Image.network(photoUrl!, fit: BoxFit.cover),
                        )
                      : Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatChip(
                            label: '$userAge yrs',
                            icon: Icons.cake_rounded,
                            color: _amber,
                          ),
                          const SizedBox(width: 8),
                          if (userGender.isNotEmpty)
                            _StatChip(
                              label:
                                  '$genderEmoji ${userGender[0].toUpperCase()}${userGender.substring(1)}',
                              color: _mint,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ActionTile(
            icon: Icons.edit_rounded,
            label: 'Edit Profile',
            subtitle: 'Update your details',
            color: _violet,
            onTap: onEdit,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.switch_account_rounded,
            label: 'Switch Account',
            subtitle: 'Login with another account',
            color: _mint,
            onTap: onSwitch,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            subtitle: 'See you soon!',
            color: _rose,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  final String initName, initGender;
  final int initAge;
  final Future<void> Function(String, int, String) onSave;
  const _EditProfileSheet({
    required this.initName,
    required this.initAge,
    required this.initGender,
    required this.onSave,
  });
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late int _age;
  late String _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initName);
    _age = widget.initAge;
    _gender = widget.initGender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genders = [
      {'label': 'Male', 'emoji': '👨', 'value': 'male', 'color': _violet},
      {'label': 'Female', 'emoji': '👩', 'value': 'female', 'color': _rose},
      {'label': 'Other', 'emoji': '🧑', 'value': 'other', 'color': _amber},
    ];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 36),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _violet.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: _violet,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // NAME
              _FieldLabel(emoji: '👋', label: 'Name'),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Your name...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  prefixIcon: Icon(
                    Icons.person_rounded,
                    color: _violet.withOpacity(0.6),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _violet, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // AGE
              Row(
                children: [
                  _FieldLabel(emoji: '🎂', label: 'Age'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _violet.withOpacity(0.2),
                          _indigo.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _violet.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$_age yrs',
                      style: const TextStyle(
                        color: _violet,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: _violet.withOpacity(0.08),
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: _violet.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        itemExtent: 46,
                        perspective: 0.003,
                        diameterRatio: 2.0,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(
                          initialItem: _age - 1,
                        ),
                        onSelectedItemChanged: (i) =>
                            setState(() => _age = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 100,
                          builder: (_, i) {
                            final age = i + 1;
                            final isSel = age == _age;
                            return Center(
                              child: Text(
                                '$age',
                                style: TextStyle(
                                  fontSize: isSel ? 24 : 17,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSel
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // GENDER
              _FieldLabel(emoji: '🧬', label: 'Gender'),
              const SizedBox(height: 12),
              Row(
                children: genders.map((g) {
                  final isSel = _gender == g['value'];
                  final col = g['color'] as Color;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _gender = g['value'] as String);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSel ? col.withOpacity(0.15) : _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel
                                ? col.withOpacity(0.6)
                                : Colors.white.withOpacity(0.07),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              g['emoji'] as String,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              g['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSel
                                    ? col
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // LOCATION
              _FieldLabel(emoji: '📍', label: 'Location Permission'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await Permission.location.request();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _violet,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text('Location permission updated!'),
                          ],
                        ),
                      ),
                    );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _mint.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _mint,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enable Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Find nearby dermatologists',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _mint.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _mint.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'Allow',
                          style: TextStyle(
                            color: _mint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // SAVE
              GestureDetector(
                onTap: _saving
                    ? null
                    : () async {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setState(() => _saving = true);
                        await widget.onSave(name, _age, _gender);
                        if (mounted) {
                          Navigator.pop(context);
                          HapticFeedback.heavyImpact();
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _saving
                          ? [Colors.grey.shade800, Colors.grey.shade700]
                          : [_violet, _indigo],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _saving
                        ? []
                        : [
                            BoxShadow(
                              color: _violet.withOpacity(0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// LOGOUT DIALOG
// ═══════════════════════════════════════════════════
class _LogoutDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutDialog({required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Log Out?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Are you sure you want to log out?',
        style: TextStyle(color: Colors.white.withOpacity(0.55)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _rose,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text(
            'Log Out',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════
class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _StatChip({required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String emoji, label;
  const _FieldLabel({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
