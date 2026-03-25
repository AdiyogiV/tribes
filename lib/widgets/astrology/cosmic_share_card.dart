import 'package:flutter/material.dart';
import 'package:aurogram/utils/astrology/zodiac_traits.dart';

/// A beautiful shareable card displaying user's cosmic profile (Rising, Sun, Moon)
/// Designed to be captured as an image for social sharing
class CosmicShareCard extends StatelessWidget {
  final String? userName;
  final String sunSign;
  final String moonSign;
  final String risingSign;
  final String? sunNakshatra;
  final String? moonNakshatra;
  final String? risingNakshatra;

  const CosmicShareCard({
    super.key,
    this.userName,
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    this.sunNakshatra,
    this.moonNakshatra,
    this.risingNakshatra,
  });

  @override
  Widget build(BuildContext context) {
    final summary = ZodiacTraits.generateSummary(
      risingSign: risingSign,
      sunSign: sunSign,
      moonSign: moonSign,
    );

    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF0f1624),
            Color(0xFF0a0e17),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            userName != null
                ? "$userName's Cosmic Blueprint"
                : 'My Cosmic Blueprint',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          // Three sign cards
          _buildSignCard(
            icon: '↑',
            iconColor: const Color(0xFF7FFFD4),
            placement: 'Rising',
            meaning: 'How others see you',
            sign: risingSign,
          ),
          const SizedBox(height: 10),
          _buildSignCard(
            icon: '☉',
            iconColor: const Color(0xFFFFD700),
            placement: 'Sun',
            meaning: 'Your core identity',
            sign: sunSign,
          ),
          const SizedBox(height: 10),
          _buildSignCard(
            icon: '☽',
            iconColor: const Color(0xFFE8E8E8),
            placement: 'Moon',
            meaning: 'Your emotional world',
            sign: moonSign,
          ),

          const SizedBox(height: 18),

          // Summary quote - the dopamine hit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // App branding
          _buildBranding(),
        ],
      ),
    );
  }

  Widget _buildSignCard({
    required String icon,
    required Color iconColor,
    required String placement,
    required String meaning,
    required String sign,
  }) {
    final traits = ZodiacTraits.getTraits(sign);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon + Placement + Sign
          Row(
            children: [
              Text(
                icon,
                style: TextStyle(fontSize: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                placement,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                sign,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bottom row: Meaning + Traits
          Row(
            children: [
              Expanded(
                child: Text(
                  meaning,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              // Trait badges
              ...traits.map((trait) => Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trait,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Aurogram',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'discover your cosmic self',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
