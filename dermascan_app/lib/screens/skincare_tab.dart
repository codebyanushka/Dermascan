import 'package:flutter/material.dart';

class SkincareTab extends StatelessWidget {
  final String? diagnosis;
  const SkincareTab({super.key, this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D0E24), Color(0xFF06060F)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34EDB3).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: Color(0xFF34EDB3),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skin Care',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (diagnosis != null)
                          Text(
                            'Tuned for $diagnosis',
                            style: const TextStyle(
                              color: Color(0xFF34EDB3),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoutineCard(
                  title: 'Morning Routine',
                  emoji: '🌅',
                  color: const Color(0xFFFFB547),
                  steps: const [
                    'Gentle cleanser — lukewarm water',
                    'Alcohol-free hydrating toner',
                    'Vitamin C or Niacinamide serum',
                    'Lightweight non-comedogenic moisturizer',
                    'SPF 30+ sunscreen — never skip!',
                  ],
                ),
                const SizedBox(height: 14),
                _RoutineCard(
                  title: 'Evening Routine',
                  emoji: '🌙',
                  color: const Color(0xFF7B6EF6),
                  steps: const [
                    'Oil cleanser + gentle face wash',
                    'Exfoliate 2–3x/week (AHA or BHA)',
                    'Retinol or Niacinamide treatment serum',
                    'Gently pat eye cream around eyes',
                    'Richer night moisturizer',
                  ],
                ),
                const SizedBox(height: 24),

                // ── Ingredients ────────────────────────────────────
                _SectionHeader(title: 'Key Ingredients'),
                const SizedBox(height: 14),
                _IngredientCard(
                  ingredients: const [
                    _Ingredient(
                      'Niacinamide',
                      'Pores + oil control',
                      true,
                      Color(0xFF34EDB3),
                    ),
                    _Ingredient(
                      'Salicylic Acid',
                      'Unclogs pores',
                      true,
                      Color(0xFF34EDB3),
                    ),
                    _Ingredient(
                      'Hyaluronic Acid',
                      'Deep hydration',
                      true,
                      Color(0xFF34EDB3),
                    ),
                    _Ingredient(
                      'Retinol',
                      'Anti-aging cell turnover',
                      true,
                      Color(0xFF34EDB3),
                    ),
                    _Ingredient(
                      'Fragrance',
                      'Irritates sensitive skin',
                      false,
                      Color(0xFFFF5E84),
                    ),
                    _Ingredient(
                      'Alcohol',
                      'Dries & breaks skin barrier',
                      false,
                      Color(0xFFFF5E84),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Lifestyle ──────────────────────────────────────
                _SectionHeader(title: 'Lifestyle Tips'),
                const SizedBox(height: 14),
                _TipsCard(
                  tips: const [
                    _Tip('💧', 'Drink 8 glasses of water daily'),
                    _Tip('😴', 'Sleep 7–8 hrs — skin repairs overnight'),
                    _Tip('🥗', 'Eat Vitamin C & E rich foods'),
                    _Tip('🚫', 'Avoid touching your face'),
                    _Tip('🧴', 'Change pillowcase every 3 days'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ── Routine card ──────────────────────────────────────────────────────────────
class _RoutineCard extends StatelessWidget {
  final String title, emoji;
  final Color color;
  final List<String> steps;
  const _RoutineCard({
    required this.title,
    required this.emoji,
    required this.color,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.65),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ingredient model ──────────────────────────────────────────────────────────
class _Ingredient {
  final String name, desc;
  final bool isGood;
  final Color color;
  const _Ingredient(this.name, this.desc, this.isGood, this.color);
}

// ── Ingredient card ───────────────────────────────────────────────────────────
class _IngredientCard extends StatelessWidget {
  final List<_Ingredient> ingredients;
  const _IngredientCard({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: ingredients
            .map(
              (ing) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ing.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        ing.isGood ? Icons.check_rounded : Icons.close_rounded,
                        color: ing.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ing.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ing.desc,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.38),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Tip model + card ──────────────────────────────────────────────────────────
class _Tip {
  final String emoji, text;
  const _Tip(this.emoji, this.text);
}

class _TipsCard extends StatelessWidget {
  final List<_Tip> tips;
  const _TipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: tips
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.text,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
