import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/current_sky_service.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';


/// Current Sky Page — The cosmic intelligence dashboard.
///
/// Shows:
/// 1. Today's top sky signals (global)
/// 2. Personal transit house readings (per-user ascendant)
/// 3. Agent predictions with validation status
///
/// Architecture: Global signals computed once, personal readings derived from ascendant batch.
class CurrentSkyPage extends StatefulWidget {
  final String uid;
  const CurrentSkyPage({super.key, required this.uid});

  @override
  State<CurrentSkyPage> createState() => _CurrentSkyPageState();
}

class _CurrentSkyPageState extends State<CurrentSkyPage> {
  final _skyService = CurrentSkyService();
  final _astroService = AstrologyService();
  String _selectedDate = '';
  TransitReading? _transitReading;
  bool _loadingTransit = false;
  String? _userAscendant;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayKey();
    _loadUserAscendant();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadUserAscendant() async {
    try {
      final profile = await _astroService.getProfile(widget.uid);
      if (profile != null && mounted) {
        setState(() {
          _userAscendant = profile.ascendant;
        });
        if (_userAscendant != null) {
          _loadTransitReading();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTransitReading() async {
    if (_userAscendant == null) return;
    setState(() => _loadingTransit = true);
    try {
      final reading = await _skyService.getTransitReading(
        _userAscendant!,
        date: _selectedDate,
      );
      if (mounted) {
        setState(() {
          _transitReading = reading;
          _loadingTransit = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Sky'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _showDatePicker,
            tooltip: 'Pick date',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            _buildDateHeader(isDark),
            const SizedBox(height: 16),

            // Global signals section
            _buildSectionHeader('Sky Signals', Icons.auto_awesome, isDark),
            const SizedBox(height: 8),
            _buildSignalsList(isDark),
            const SizedBox(height: 24),

            // Personal transit houses
            if (_userAscendant != null) ...[
              _buildSectionHeader(
                'Your Transits — $_userAscendant Rising',
                Icons.person_outline,
                isDark,
              ),
              const SizedBox(height: 8),
              _buildTransitHouses(isDark),
              const SizedBox(height: 24),
            ],

            // Agent predictions
            _buildSectionHeader('Agent Predictions', Icons.psychology, isDark),
            const SizedBox(height: 8),
            _buildPredictionsList(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDateHeader(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _selectedDate,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalsList(bool isDark) {
    return StreamBuilder<List<SkySignal>>(
      stream: _skyService.streamTodaySignals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final signals = snapshot.data ?? [];
        if (signals.isEmpty) {
          return _buildEmptyState('No signals computed yet for today.', isDark);
        }

        return Column(
          children: signals.map((signal) => _buildSignalCard(signal, isDark)).toList(),
        );
      },
    );
  }

  Widget _buildSignalCard(SkySignal signal, bool isDark) {
    final color = _getSignalColor(signal.colorCategory);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Intensity badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${signal.intensity}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Signal description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.description,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signal.domains.take(3).join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                signal.status,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransitHouses(bool isDark) {
    if (_loadingTransit) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_transitReading == null) {
      return _buildEmptyState('Transit readings not available yet.', isDark);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final houseNum = index + 1;
        final house = _transitReading!.houses[houseNum];
        if (house == null) return const SizedBox();

        return _buildHouseTile(house, isDark);
      },
    );
  }

  Widget _buildHouseTile(HouseReading house, bool isDark) {
    final hasContent = house.hasTransits || house.reading != null;
    final tileColor = _getHouseColor(house.houseNumber);

    return GestureDetector(
      onTap: () => _showTransitHouseDialog(house),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasContent
              ? tileColor.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasContent
                ? tileColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'H${house.houseNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasContent ? tileColor : (isDark ? Colors.white30 : Colors.black26),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              house.sign,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            if (house.transitPlanets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  house.transitPlanets
                      .map((p) => _planetEmoji(p['planet'] ?? ''))
                      .join(' '),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsList(bool isDark) {
    return StreamBuilder<List<AgentPrediction>>(
      stream: _skyService.streamRecentPredictions(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final predictions = snapshot.data ?? [];
        if (predictions.isEmpty) {
          return _buildEmptyState(
            'No predictions yet. The agent will start making predictions after observing patterns.',
            isDark,
          );
        }

        return Column(
          children: predictions.map((p) => _buildPredictionCard(p, isDark)).toList(),
        );
      },
    );
  }

  Widget _buildPredictionCard(AgentPrediction prediction, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(prediction.statusEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prediction.claim,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildChip('${(prediction.confidence * 100).toInt()}%', isDark),
                const SizedBox(width: 6),
                ...prediction.domains
                    .take(2)
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildChip(d, isDark),
                        )),
                const Spacer(),
                if (prediction.brierScore != null)
                  Text(
                    'Brier: ${prediction.brierScore!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white30 : Colors.black26,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.white30 : Colors.black26,
          fontSize: 13,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showTransitHouseDialog(HouseReading house) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    'House ${house.houseNumber} — ${house.houseName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${house.sign} · Lord: ${house.signLord}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getHouseColor(house.houseNumber),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Planets in this house
                  if (house.transitPlanets.isNotEmpty) ...[
                    Text(
                      'Transit Planets',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: house.transitPlanets.map((p) {
                        final isRetro = p['isRetro'] == true;
                        return Chip(
                          label: Text(
                            '${_planetEmoji(p['planet'] ?? '')} ${p['planet']}${isRetro ? ' (R)' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // AI Reading
                  if (house.reading != null) ...[
                    Text(
                      'Transit Reading',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      house.reading!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75),
                      ),
                    ),
                  ] else
                    _buildEmptyState('No reading available for this house today.', isDark),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      final key = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _selectedDate = key);
      _loadTransitReading();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getSignalColor(String category) {
    switch (category) {
      case 'red':
        return Colors.redAccent;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.greenAccent.shade700;
      case 'amber':
        return Colors.amber;
      case 'purple':
        return Colors.purpleAccent;
      case 'blue':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Color _getHouseColor(int house) {
    // Kendra = amber, Trikona = green, Dusthana = red, Upachaya = blue
    if ([1, 4, 7, 10].contains(house)) return Colors.amber;
    if ([1, 5, 9].contains(house)) return Colors.greenAccent.shade700;
    if ([6, 8, 12].contains(house)) return Colors.redAccent;
    if ([3, 6, 10, 11].contains(house)) return Colors.blueAccent;
    return Colors.grey;
  }

  String _planetEmoji(String planet) {
    const emojis = {
      'Sun': '☀️', 'Moon': '🌙', 'Mars': '♂️', 'Mercury': '☿️',
      'Jupiter': '♃', 'Venus': '♀️', 'Saturn': '♄', 'Rahu': '🐍',
      'Ketu': '🔥', 'Uranus': '⛢', 'Neptune': '♆', 'Pluto': '♇',
    };
    return emojis[planet] ?? '●';
  }
}
