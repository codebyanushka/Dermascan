import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _violet = Color(0xFF7B6EF6);
const _mint = Color(0xFF34EDB3);
const _amber = Color(0xFFFFB547);
const _rose = Color(0xFFFF5E84);
const _ink = Color(0xFF06060F);

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await _plugin.initialize(settings);

  // Create notification channel
  const channel = AndroidNotificationChannel(
    'dermascan_reminders',
    'Skin Care Reminders',
    description: 'Daily skin care reminders',
    importance: Importance.high,
    playSound: true,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<void> _showNotif(int id, String title, String body) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'dermascan_reminders',
      'Skin Care Reminders',
      channelDescription: 'Daily skin care reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    ),
  );
  await _plugin.show(id, title, body, details);
}

Future<void> _cancelNotif(int id) async {
  await _plugin.cancel(id);
}

// ─────────────────────────────────────────────────────────────────────────────

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<_Reminder> _reminders = [];

  final List<Map<String, dynamic>> _presets = [
    {
      'title': '🌅 Morning Skincare',
      'body': 'Time for your morning routine!',
      'hour': 7,
      'min': 0,
      'color': _amber,
      'icon': Icons.wb_sunny_rounded,
    },
    {
      'title': '🌙 Evening Skincare',
      'body': 'Don\'t forget your evening routine!',
      'hour': 21,
      'min': 0,
      'color': _violet,
      'icon': Icons.nightlight_round,
    },
    {
      'title': '💊 Take Medicine',
      'body': 'Time to take your skin medicine!',
      'hour': 9,
      'min': 0,
      'color': _rose,
      'icon': Icons.medication_rounded,
    },
    {
      'title': '💧 Drink Water',
      'body': 'Stay hydrated for healthy skin!',
      'hour': 12,
      'min': 0,
      'color': _mint,
      'icon': Icons.water_drop_rounded,
    },
    {
      'title': '☀️ Apply Sunscreen',
      'body': 'Reapply your SPF protection!',
      'hour': 10,
      'min': 0,
      'color': _amber,
      'icon': Icons.light_mode_rounded,
    },
    {
      'title': '🧴 Moisturizer Time',
      'body': 'Keep your skin moisturized!',
      'hour': 22,
      'min': 0,
      'color': _mint,
      'icon': Icons.spa_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reminders') ?? '[]';
    setState(() {
      _reminders = (jsonDecode(raw) as List)
          .map((e) => _Reminder.fromJson(e))
          .toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminders',
      jsonEncode(_reminders.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _addPreset(Map<String, dynamic> preset) async {
    HapticFeedback.mediumImpact();
    if (_reminders.any((r) => r.title == preset['title'])) {
      _showSnack('Already added!');
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: preset['hour'], minute: preset['min']),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _violet),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF12121F),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    final reminder = _Reminder(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: preset['title'],
      body: preset['body'],
      hour: picked.hour,
      minute: picked.minute,
      enabled: true,
      color: (preset['color'] as Color).value,
    );

    setState(() => _reminders.add(reminder));
    await _save();

    // Show confirmation notification with sound
    try {
      await _showNotif(
        reminder.id,
        reminder.title,
        '✅ Reminder set for ${picked.format(context)}!',
      );
    } catch (e) {
      debugPrint('Notif error: $e');
    }

    if (mounted) _showSnack('Reminder set for ${picked.format(context)} ✅');
  }

  Future<void> _toggle(_Reminder r) async {
    HapticFeedback.selectionClick();
    setState(() {
      final i = _reminders.indexWhere((x) => x.id == r.id);
      if (i >= 0) _reminders[i] = r.copyWith(enabled: !r.enabled);
    });
    await _save();
  }

  Future<void> _delete(_Reminder r) async {
    HapticFeedback.mediumImpact();
    setState(() => _reminders.removeWhere((x) => x.id == r.id));
    try {
      await _cancelNotif(r.id);
    } catch (_) {}
    await _save();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _violet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.alarm_rounded,
                        color: _amber,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Daily skin care alerts',
                          style: TextStyle(color: _amber, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Active reminders
            if (_reminders.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Active (${_reminders.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ReminderTile(
                    reminder: _reminders[i],
                    onToggle: _toggle,
                    onDelete: _delete,
                  ),
                  childCount: _reminders.length,
                ),
              ),
            ] else
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.alarm_rounded,
                            color: _amber.withOpacity(0.4),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reminders yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add one from below!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Quick add section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: const Text(
                  'Quick Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final p = _presets[i];
                final added = _reminders.any((r) => r.title == p['title']);
                return _PresetTile(
                  preset: p,
                  added: added,
                  onTap: () => _addPreset(p),
                );
              }, childCount: _presets.length),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Reminder tile ─────────────────────────────────────────────────────────────
class _ReminderTile extends StatelessWidget {
  final _Reminder reminder;
  final Function(_Reminder) onToggle;
  final Function(_Reminder) onDelete;
  const _ReminderTile({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(reminder.color);
    final time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);

    return Dismissible(
      key: Key('rem_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        decoration: BoxDecoration(
          color: _rose.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: _rose, size: 24),
      ),
      onDismissed: (_) => onDelete(reminder),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: reminder.enabled
              ? color.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reminder.enabled
                ? color.withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(reminder.enabled ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.alarm_rounded,
                color: reminder.enabled ? color : Colors.white.withOpacity(0.2),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      color: reminder.enabled
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} daily',
                    style: TextStyle(
                      color: reminder.enabled
                          ? color
                          : Colors.white.withOpacity(0.2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: reminder.enabled,
              onChanged: (_) => onToggle(reminder),
              activeColor: color,
              activeTrackColor: color.withOpacity(0.25),
              inactiveThumbColor: Colors.white.withOpacity(0.3),
              inactiveTrackColor: Colors.white.withOpacity(0.08),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preset tile ───────────────────────────────────────────────────────────────
class _PresetTile extends StatelessWidget {
  final Map<String, dynamic> preset;
  final bool added;
  final VoidCallback onTap;
  const _PresetTile({
    required this.preset,
    required this.added,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = preset['color'] as Color;
    return GestureDetector(
      onTap: added ? null : onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(preset['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    preset['body'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: added ? _mint.withOpacity(0.1) : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: added
                      ? _mint.withOpacity(0.3)
                      : color.withOpacity(0.3),
                ),
              ),
              child: Text(
                added ? '✓ Added' : '+ Add',
                style: TextStyle(
                  color: added ? _mint : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class _Reminder {
  final int id, hour, minute, color;
  final String title, body;
  final bool enabled;

  const _Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.color,
  });

  _Reminder copyWith({bool? enabled}) => _Reminder(
    id: id,
    title: title,
    body: body,
    hour: hour,
    minute: minute,
    color: color,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'color': color,
  };

  factory _Reminder.fromJson(Map<String, dynamic> j) => _Reminder(
    id: j['id'],
    title: j['title'],
    body: j['body'],
    hour: j['hour'],
    minute: j['minute'],
    enabled: j['enabled'],
    color: j['color'],
  );
}
