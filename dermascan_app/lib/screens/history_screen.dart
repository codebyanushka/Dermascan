import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

const String _API = 'http://10.0.2.2:5001';

const _violet = Color(0xFF7B6EF6);
const _mint = Color(0xFF34EDB3);
const _amber = Color(0xFFFFB547);
const _rose = Color(0xFFFF5E84);
const _ink = Color(0xFF06060F);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _scans = [];
  bool _loadingScans = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchScans();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchScans() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingScans = false);
      return;
    }
    try {
      final res = await http
          .get(Uri.parse('$_API/get-scans?uid=$uid'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _scans = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _loadingScans = false;
        });
      } else {
        setState(() => _loadingScans = false);
      }
    } catch (_) {
      setState(() => _loadingScans = false);
    }
  }

  Color _sevColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'mild':
        return _mint;
      case 'moderate':
        return _amber;
      case 'severe':
        return _rose;
      default:
        return _violet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: _ink,
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            title: const Text(
              'My DermaCam',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: _violet,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.35),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '🧬  Scan History'),
                    Tab(text: '📍  Find Dermat'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _ScanHistoryTab(
              scans: _scans,
              loading: _loadingScans,
              sevColor: _sevColor,
              onRefresh: _fetchScans,
            ),
            const _FindDermatTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SCAN HISTORY
// ════════════════════════════════════════════════════════════════════════════
class _ScanHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> scans;
  final bool loading;
  final Color Function(String?) sevColor;
  final Future<void> Function() onRefresh;

  const _ScanHistoryTab({
    required this.scans,
    required this.loading,
    required this.sevColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _violet, strokeWidth: 2),
      );
    }
    if (scans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _violet.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.biotech_rounded,
                color: _violet,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No scans yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan your first skin condition!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _violet,
      backgroundColor: const Color(0xFF12121F),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: scans.length,
        itemBuilder: (_, i) => _ScanCard(scan: scans[i], sevColor: sevColor),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final Color Function(String?) sevColor;
  const _ScanCard({required this.scan, required this.sevColor});

  @override
  Widget build(BuildContext context) {
    final diagnosis = scan['diagnosis'] ?? 'Unknown';
    final severity = scan['severity'] ?? 'mild';
    final confidence = scan['confidence'] ?? 0;
    final category = scan['category'] ?? '';
    final raw = scan['created_at']?.toString() ?? '';
    final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
    final color = sevColor(severity);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.biotech_rounded, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (category.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$confidence%',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    HapticFeedback.lightImpact();
    final color = sevColor(scan['severity']);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1E),
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
              Expanded(
                child: ListView(
                  controller: ctrl,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.biotech_rounded,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            scan['diagnosis'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if ((scan['what_is_this'] ?? '').isNotEmpty)
                      _DS(title: '💬 What is this', body: scan['what_is_this']),
                    if ((scan['is_serious'] ?? '').isNotEmpty)
                      _DS(title: '⚠️ Seriousness', body: scan['is_serious']),
                    if ((scan['home_remedies'] ?? '').isNotEmpty)
                      _DS(
                        title: '🌿 Home Remedies',
                        body: scan['home_remedies'],
                      ),
                    if ((scan['medicine'] ?? '').isNotEmpty)
                      _DS(title: '💊 Medicine', body: scan['medicine']),
                    if ((scan['doctor_advice'] ?? '').isNotEmpty)
                      _DS(
                        title: '👨‍⚕️ See Doctor If',
                        body: scan['doctor_advice'],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DS extends StatelessWidget {
  final String title;
  final dynamic body;
  const _DS({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final text = body is List
        ? (body as List).join(', ')
        : body?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FIND DERMAT — GPS + MAP
// ════════════════════════════════════════════════════════════════════════════
class _FindDermatTab extends StatefulWidget {
  const _FindDermatTab();

  @override
  State<_FindDermatTab> createState() => _FindDermatTabState();
}

class _FindDermatTabState extends State<_FindDermatTab> {
  Position? _pos;
  bool _locLoading = false;
  bool _showMap = false;
  final MapController _mapCtrl = MapController();

  static const List<Map<String, dynamic>> _clinics = [
    {
      'name': 'AIIMS Dermatology',
      'address': 'Ansari Nagar, New Delhi',
      'rating': '4.8',
      'distance': '2.1 km',
      'type': 'Government',
      'lat': 28.5672,
      'lng': 77.2100,
    },
    {
      'name': 'Fortis Skin Clinic',
      'address': 'Sector 62, Noida',
      'rating': '4.5',
      'distance': '3.4 km',
      'type': 'Private',
      'lat': 28.6270,
      'lng': 77.3710,
    },
    {
      'name': 'Apollo Dermatology',
      'address': 'Connaught Place, Delhi',
      'rating': '4.6',
      'distance': '5.0 km',
      'type': 'Private',
      'lat': 28.6315,
      'lng': 77.2167,
    },
    {
      'name': 'Skin & You Clinic',
      'address': 'Lajpat Nagar, Delhi',
      'rating': '4.3',
      'distance': '6.2 km',
      'type': 'Specialist',
      'lat': 28.5700,
      'lng': 77.2430,
    },
    {
      'name': 'Max Super Speciality',
      'address': 'Saket, New Delhi',
      'rating': '4.7',
      'distance': '8.5 km',
      'type': 'Private',
      'lat': 28.5244,
      'lng': 77.2066,
    },
  ];

  Future<void> _getLocation() async {
    setState(() => _locLoading = true);
    try {
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        _showSnack('Please enable location services');
        setState(() => _locLoading = false);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied');
        setState(() => _locLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _pos = pos;
        _locLoading = false;
        _showMap = true;
      });
    } catch (e) {
      setState(() => _locLoading = false);
      _showSnack('Could not get location: $e');
    }
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

  Color _typeColor(String? t) {
    if (t == 'Government') return _mint;
    if (t == 'Specialist') return _amber;
    return _violet;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── Map / Location section ──────────────────────────────────
        if (_showMap && _pos != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(_pos!.latitude, _pos!.longitude),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.dermascan_app',
                  ),
                  MarkerLayer(
                    markers: [
                      // User location
                      Marker(
                        point: LatLng(_pos!.latitude, _pos!.longitude),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _violet,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: _violet.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Clinic markers
                      ..._clinics.map(
                        (c) => Marker(
                          point: LatLng(c['lat'], c['lng']),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _typeColor(c['type']),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Location found banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _mint.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, color: _mint, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Location found · ${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _getLocation,
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: _mint,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // GPS prompt card
          GestureDetector(
            onTap: _getLocation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_violet.withOpacity(0.15), _mint.withOpacity(0.08)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _violet.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _violet.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: _locLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              color: _violet,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.location_on_rounded,
                            color: _violet,
                            size: 26,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Find Nearby Dermatologists',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _locLoading
                              ? 'Getting your location...'
                              : 'Tap to enable GPS & show map',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_locLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _violet.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _violet.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Enable',
                        style: TextStyle(
                          color: _violet,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Clinics list ───────────────────────────────────────────
        Text(
          '${_clinics.length} Dermatologists Found',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),

        ..._clinics.map((c) => _ClinicCard(clinic: c, typeColor: _typeColor)),
      ],
    );
  }
}

class _ClinicCard extends StatelessWidget {
  final Map<String, dynamic> clinic;
  final Color Function(String?) typeColor;
  const _ClinicCard({required this.clinic, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final color = typeColor(clinic['type']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.local_hospital_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinic['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  clinic['address']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        clinic['type']!,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, color: _amber, size: 13),
                    const SizedBox(width: 2),
                    Text(
                      clinic['rating']!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                clinic['distance']!,
                style: const TextStyle(
                  color: _violet,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _violet.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_rounded,
                  color: _violet,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
