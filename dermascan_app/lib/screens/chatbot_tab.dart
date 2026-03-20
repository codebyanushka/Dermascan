import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String _CHAT_API = 'http://10.0.2.2:5001';

class ChatbotTab extends StatefulWidget {
  final String? diagnosis;
  const ChatbotTab({super.key, this.diagnosis});

  @override
  State<ChatbotTab> createState() => _ChatbotTabState();
}

class _ChatbotTabState extends State<ChatbotTab> with TickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  bool _isTyping = false;
  bool _historyOpen = false;

  late AnimationController _dotCtrl;

  // Persisted sessions
  List<_Session> _sessions = [];
  String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

  static const _violet = Color(0xFF7B6EF6);
  static const _rose = Color(0xFFFF5E84);
  static const _ink = Color(0xFF06060F);

  final List<String> _quickReplies = [
    'Ye kitna serious hai?',
    'Best treatment kya hai?',
    'Ghar pe kya karun?',
    'Doctor kab dikhana chahiye?',
    'Kitne din mein theek hoga?',
  ];

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _loadSessions();
    _addWelcome();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  void _addWelcome() {
    _messages.add(
      _Msg(
        role: 'bot',
        text: widget.diagnosis != null
            ? 'Hi! 👋 I\'ve analyzed your scan — **${widget.diagnosis}** detected. Ask me anything!'
            : 'Hi! 👋 I\'m DermAI. Upload a skin photo first, or ask me anything about skin care!',
        time: DateTime.now(),
      ),
    );
  }

  // ── Persist sessions ────────────────────────────────────────────────────
  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_sessions') ?? '[]';
    final list = (jsonDecode(raw) as List);
    setState(() {
      _sessions = list.map((e) => _Session.fromJson(e)).toList();
    });
  }

  Future<void> _saveCurrent() async {
    if (_messages.length <= 1) return; // only welcome msg
    final prefs = await SharedPreferences.getInstance();
    final session = _Session(
      id: _sessionId,
      title: _messages.length > 1
          ? _messages[1].text.substring(
              0,
              _messages[1].text.length.clamp(0, 40),
            )
          : 'Chat',
      messages: _messages,
      createdAt: DateTime.now(),
    );
    final existing = _sessions.indexWhere((s) => s.id == _sessionId);
    if (existing >= 0) {
      _sessions[existing] = session;
    } else {
      _sessions.insert(0, session);
    }
    if (_sessions.length > 20) _sessions = _sessions.sublist(0, 20);
    await prefs.setString(
      'chat_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
    setState(() {});
  }

  void _loadSession(_Session s) {
    setState(() {
      _messages.clear();
      _messages.addAll(s.messages);
      _sessionId = s.id;
      _historyOpen = false;
    });
    _scrollToBottom();
  }

  void _newChat() {
    _saveCurrent();
    setState(() {
      _messages.clear();
      _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _historyOpen = false;
    });
    _addWelcome();
  }

  // ── Send ────────────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _msgCtrl.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', text: text, time: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final res = await http
          .post(
            Uri.parse('$_CHAT_API/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': text,
              'session_id': _sessionId,
              'diagnosis': widget.diagnosis,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)['reply'] ?? 'Sorry, try again.')
          : 'Server error. Please try again.';

      setState(() {
        _isTyping = false;
        _messages.add(_Msg(role: 'bot', text: reply, time: DateTime.now()));
      });
    } catch (_) {
      setState(() {
        _isTyping = false;
        _messages.add(
          _Msg(
            role: 'bot',
            text: 'Connection error. Make sure the server is running.',
            time: DateTime.now(),
          ),
        );
      });
    }
    _scrollToBottom();
    _saveCurrent();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_historyOpen) _buildHistoryPanel() else _buildChat(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
      decoration: BoxDecoration(
        color: _ink,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_violet, Color(0xFF4F46E5)],
              ),
              boxShadow: [
                BoxShadow(color: _violet.withOpacity(0.4), blurRadius: 12),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DermAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34EDB3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online · AI Skin Assistant',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // History toggle
          _HeaderBtn(
            icon: _historyOpen
                ? Icons.chat_bubble_rounded
                : Icons.history_rounded,
            onTap: () => setState(() => _historyOpen = !_historyOpen),
          ),
          const SizedBox(width: 6),
          // New chat
          _HeaderBtn(icon: Icons.add_rounded, onTap: _newChat),
        ],
      ),
    );
  }

  // ── HISTORY PANEL ────────────────────────────────────────────────────────
  Widget _buildHistoryPanel() {
    return Expanded(
      child: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: Colors.white.withOpacity(0.15),
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No previous chats',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _sessions.length,
              itemBuilder: (_, i) {
                final s = _sessions[i];
                final isActive = s.id == _sessionId;
                return GestureDetector(
                  onTap: () => _loadSession(s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? _violet.withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? _violet.withOpacity(0.35)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _violet.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: _violet,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${s.messages.length} messages · ${_fmt(s.createdAt)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _violet,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ── CHAT ─────────────────────────────────────────────────────────────────
  Widget _buildChat() {
    return Expanded(
      child: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isTyping) {
                  return _buildTyping();
                }
                return _buildBubble(_messages[i]);
              },
            ),
          ),

          // Quick replies
          if (_messages.length <= 2)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: _quickReplies
                    .map(
                      (q) => GestureDetector(
                        onTap: () => _send(q),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _violet.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _violet.withOpacity(0.3)),
                          ),
                          child: Text(
                            q,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _violet,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_violet, Color(0xFF4F46E5)]),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [_violet, Color(0xFF4F46E5)],
                          )
                        : null,
                    color: isUser ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: _violet.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser
                          ? Colors.white
                          : Colors.white.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmtTime(msg.time),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_violet, Color(0xFF4F46E5)]),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) {
                    final v = ((_dotCtrl.value * 3 - i).clamp(0.0, 1.0));
                    final opacity = v < 0.5 ? v * 2 : (1 - v) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _violet.withOpacity(opacity.clamp(0.2, 1.0)),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1C),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask about your skin...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_msgCtrl.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_violet, Color(0xFF4F46E5)],
                ),
                boxShadow: [
                  BoxShadow(color: _violet.withOpacity(0.4), blurRadius: 12),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime d) =>
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Models ────────────────────────────────────────────────────────────────────
class _Msg {
  final String role, text;
  final DateTime time;
  _Msg({required this.role, required this.text, required this.time});

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'time': time.toIso8601String(),
  };

  factory _Msg.fromJson(Map<String, dynamic> j) =>
      _Msg(role: j['role'], text: j['text'], time: DateTime.parse(j['time']));
}

class _Session {
  final String id, title;
  final List<_Msg> messages;
  final DateTime createdAt;
  _Session({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
    id: j['id'],
    title: j['title'],
    createdAt: DateTime.parse(j['createdAt']),
    messages: (j['messages'] as List).map((m) => _Msg.fromJson(m)).toList(),
  );
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.6), size: 18),
      ),
    );
  }
}
