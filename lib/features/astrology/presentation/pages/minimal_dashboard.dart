import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/shared/models/daily_insight.dart';

class MinimalDashboardPage extends StatelessWidget {
  const MinimalDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Force dark mode for the cosmic aesthetic
    const bgColor = Color(0xFF09080C); 
    const fgColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: fgColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: user == null
          ? const Center(child: Text("Login Required", style: TextStyle(color: fgColor)))
          : StreamBuilder<DailyInsight?>(
              stream: AstrologyService().streamTodayInsight(user.uid),
              builder: (context, snapshot) {
                final insight = snapshot.data;
                
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 100), // Space for AppBar

                      // 1. IDENTITY & GREETING
                      Text(
                        "Today's Aura",
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w500,
                          color: fgColor.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 2. THE VISUAL HOOK (Glowing Cosmic Orb)
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF8A2BE2), // Soft Purple
                                Color(0xFF4B0082), // Deep Purple
                                Colors.transparent,
                              ],
                              stops: [0.2, 0.6, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8A2BE2).withOpacity(0.4),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              insight?.displayTheme.toUpperCase() ?? "CLARITY",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                letterSpacing: 4.0,
                                fontWeight: FontWeight.bold,
                                color: fgColor,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // 3. THE BITE-SIZED INSIGHT
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          insight?.displayMessage ?? "A sudden shift in perspective allows you to see a hidden truth. Trust your intuition over logic today.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'InstrumentSerif',
                            fontSize: 24,
                            height: 1.3,
                            color: fgColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // 4. ACTIONABLE, BEAUTIFUL CARDS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Expanded(child: _buildGlassCard(Icons.chat_bubble_outline, "Ask AI", "Deep dive")),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGlassCard(Icons.favorite_border, "Match", "Check vibes")),
                            const SizedBox(width: 16),
                            Expanded(child: _buildGlassCard(Icons.auto_graph, "Chart", "Transits")),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildGlassCard(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
