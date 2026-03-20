import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});

  // ── Safe converters ───────────────────────────────────────────────────────
  /// Backend kabhi String, kabhi List bhejta hai — dono handle karo
  static String _str(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is List) return val.map((e) => e.toString()).join(', ');
    return val.toString();
  }

  static List<String> _list(dynamic val) {
    if (val == null) return [];
    if (val is List)
      return val.map((e) => e.toString()).join('').isEmpty
          ? []
          : val.map((e) => e.toString()).toList();
    if (val is String && val.isNotEmpty) {
      // comma-separated string bhi list mein convert karo
      return val
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'mild':
        return const Color(0xFF4CAF50);
      case 'moderate':
        return const Color(0xFFFF9800);
      case 'severe':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Safe extraction ───────────────────────────────────────────────────
    final diagnosis = _str(result['diagnosis']).ifEmpty('Unknown');
    final scientific = _str(result['scientific_name']);
    final severity = _str(result['severity']).ifEmpty('mild');
    final confidence = (result['confidence'] as num?) ?? 0;
    final whatIsThis = _str(result['what_is_this']);
    final isSerious = _str(result['is_serious']);
    final homeRemedies = _str(result['home_remedies']);
    final medicine = _str(result['medicine']);
    final doctorAdvice = _str(result['doctor_advice']);
    final prevention = _str(result['prevention']);
    final agreement = _str(result['vision_agreement']);

    final causes = _list(result['causes']);
    final symptoms = _list(result['symptoms']);
    final ingredientsUse = _list(result['ingredients_use']);
    final ingredientsAvoid = _list(result['ingredients_avoid']);
    final morningRoutine = _list(result['morning_routine']);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0F),
            expandedHeight: 0,
            floating: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Diagnosis',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Main result card ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _severityColor(severity).withOpacity(0.15),
                          const Color(0xFF1A1A2E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _severityColor(severity).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill(
                              label: severity.toUpperCase(),
                              color: _severityColor(severity),
                            ),
                            const Spacer(),
                            if (agreement.isNotEmpty)
                              _Pill(
                                label: '$agreement models agree',
                                color: const Color(0xFF6C63FF),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          diagnosis,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (scientific.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            scientific,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.4),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'AI Confidence',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$confidence%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: confidence / 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _severityColor(severity),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (whatIsThis.isNotEmpty)
                    _buildSection(
                      '💬 What is this?',
                      child: _bodyText(whatIsThis),
                    ),

                  if (isSerious.isNotEmpty)
                    _buildSection(
                      '⚠️ Is it serious?',
                      child: _bodyText(isSerious),
                    ),

                  if (causes.isNotEmpty)
                    _buildSection('🔎 Likely Causes', child: _chips(causes)),

                  if (symptoms.isNotEmpty)
                    _buildSection('😣 Symptoms', child: _chips(symptoms)),

                  if (homeRemedies.isNotEmpty)
                    _buildSection(
                      '🌿 Home Remedies',
                      child: _bodyText(homeRemedies),
                    ),

                  if (medicine.isNotEmpty)
                    _buildSection(
                      '💊 OTC Medicine',
                      child: _bodyText(medicine),
                    ),

                  if (ingredientsUse.isNotEmpty)
                    _buildSection(
                      '✅ Ingredients to Use',
                      child: _chips(ingredientsUse, color: Colors.green),
                    ),

                  if (ingredientsAvoid.isNotEmpty)
                    _buildSection(
                      '❌ Ingredients to Avoid',
                      child: _chips(ingredientsAvoid, color: Colors.red),
                    ),

                  if (morningRoutine.isNotEmpty)
                    _buildSection(
                      '🌅 Morning Routine',
                      child: _numberedList(morningRoutine),
                    ),

                  if (doctorAdvice.isNotEmpty)
                    _buildSection(
                      '👨‍⚕️ See a Doctor If...',
                      child: _bodyText(doctorAdvice),
                      color: Colors.orange.withOpacity(0.1),
                      borderColor: Colors.orange.withOpacity(0.3),
                    ),

                  if (prevention.isNotEmpty)
                    _buildSection(
                      '🛡️ Prevention',
                      child: _bodyText(prevention),
                    ),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⚕️ This AI analysis is for informational purposes only and does not constitute medical advice. Always consult a qualified dermatologist.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _bodyText(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      color: Colors.white.withOpacity(0.7),
      height: 1.6,
    ),
  );

  Widget _chips(List<String> items, {Color? color}) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: items.map((e) => _buildChip(e, color: color)).toList(),
  );

  Widget _numberedList(List<String> items) => Column(
    children: items.asMap().entries.map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${e.key + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _bodyText(e.value)),
          ],
        ),
      );
    }).toList(),
  );

  Widget _buildSection(
    String title, {
    required Widget child,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildChip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF6C63FF)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (color ?? const Color(0xFF6C63FF)).withOpacity(0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color ?? const Color(0xFF9C88FF),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Pill widget ───────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── String extension ──────────────────────────────────────────────────────────
extension _StringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
