import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/shared/models/daily_insight.dart';

class MeloohaDashboardPage extends StatefulWidget {
  const MeloohaDashboardPage({super.key});

  @override
  State<MeloohaDashboardPage> createState() => _MeloohaDashboardPageState();
}

class _MeloohaDashboardPageState extends State<MeloohaDashboardPage> {
  late DateTime _selectedDate;
  final List<DateTime> _weekDays = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    for (int i = -1; i <= 5; i++) {
      _weekDays.add(_selectedDate.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Ethereal / Hyper-minimal palette (softer, less aggressive)
    final bgColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFFCFCFC);
    final primaryColor = isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF2A2A2A);
    final mutedColor = isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: mutedColor),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: user == null
          ? Center(child: Text("please login", style: TextStyle(color: mutedColor, fontSize: 14)))
          : Column(
              children: [
                // 1. WHISPER THIN WEEK STRIP
                _buildDelicateDateStrip(primaryColor, mutedColor),
                
                const SizedBox(height: 20),
                
                // 2. MAIN CONTENT AREA
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The Insight
                        StreamBuilder<DailyInsight?>(
                          stream: AstrologyService().streamTodayInsight(user.uid),
                          builder: (context, snapshot) {
                            final insight = snapshot.data;
                            final isToday = _selectedDate.difference(DateTime.now()).inDays == 0;
                            
                            final title = isToday ? (insight?.displayTheme ?? "energy") : "upcoming";
                            final message = isToday 
                                ? (insight?.displayMessage ?? "the stars are quiet...") 
                                : "the moon shifts phases. pay attention to subtle internal changes.";

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.toLowerCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.w300, // Very light
                                    color: mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  message.toLowerCase(),
                                  style: TextStyle(
                                    fontFamily: 'InstrumentSerif',
                                    fontSize: 32, // Slightly smaller
                                    height: 1.3, // More breathing room between lines
                                    fontWeight: FontWeight.w400, // Normal, not bold
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        
                        const SizedBox(height: 60),

                        // Delicate Areas
                        _buildDelicateAreaRow("career", "favorable", primaryColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildDelicateAreaRow("love", "watchful", primaryColor, mutedColor),
                        const SizedBox(height: 12),
                        _buildDelicateAreaRow("health", "peaking", primaryColor, mutedColor),

                        const SizedBox(height: 80),
                        
                        // Whisper CTA
                        Center(
                          child: InkWell(
                            onTap: () {},
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'ask aryabhatt \u2192', // tiny arrow
                                style: TextStyle(
                                  fontFamily: 'InstrumentSerif',
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  color: mutedColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDelicateDateStrip(Color primaryColor, Color mutedColor) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _weekDays.length,
        itemBuilder: (context, index) {
          final date = _weekDays[index];
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
          final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 45,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.transparent, // expand tap area
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toLowerCase().substring(0, 2), // mo, tu
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: isSelected ? primaryColor : mutedColor.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: 'InstrumentSerif',
                      fontSize: 20,
                      color: isSelected ? primaryColor : mutedColor.withOpacity(0.3),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    )
                  ] else if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(color: mutedColor.withOpacity(0.3), shape: BoxShape.circle),
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDelicateAreaRow(String label, String status, Color primaryColor, Color mutedColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.0,
            color: mutedColor,
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
}
