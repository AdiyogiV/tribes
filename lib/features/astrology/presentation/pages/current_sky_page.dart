import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/current_sky_service.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';

/// Current Sky Page — Global Cosmic Intelligence Dashboard.
///
/// Shows:
/// 1. World energy summary (1-2 paragraphs)
/// 2. Top sky signals (aspects, dignities)
/// 3. Concrete predictions with timeframes
/// 4. 12 mundane houses — tappable for detailed readings
class CurrentSkyPage extends StatefulWidget {
  final String uid;
  const CurrentSkyPage({super.key, required this.uid});

  @override
  State<CurrentSkyPage> createState() => _CurrentSkyPageState();
}

class _CurrentSkyPageState extends State<CurrentSkyPage> {
  final _skyService = CurrentSkyService();
  final _astroService = AstrologyService();
  late String _selectedDate;
  /// Bumps [FutureBuilder] for non-today dates after a manual run.
  int _refreshNonce = 0;
  bool _generating = false;
  bool _generatingHouses = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayKey();
  }

  /// Calls `generatePerHouseNow` (asia-southeast2) — force-regenerates the
  /// biweekly per-house current-state readings. After this returns success,
  /// the per-house popup on HolyCow's Current Sky chart will show the gold
  /// "RIGHT NOW" gradient block populated for all 12 houses.
  Future<void> _runPerHouse() async {
    if (_generatingHouses) return;
    setState(() => _generatingHouses = true);
    try {
      final r = await _astroService.generatePerHouseReadings(force: true);
      if (!mounted) return;
      final ok = r['success'] == true;
      final msg = ok
          ? (r['alreadyFresh'] == true
              ? '✅ Already fresh — ${r['houseCount'] ?? 12} houses cached.'
              : '✅ Generated ${r['houseCount'] ?? 12} houses. Tap a house on HolyCow.')
          : '❌ [${r['code']}] ${r['message']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? null : Colors.red.shade800,
          duration: Duration(seconds: ok ? 4 : 10),
          action: ok
              ? null
              : SnackBarAction(
                  label: 'Copy',
                  textColor: Colors.white,
                  onPressed: () {
                    // ignore: avoid_print
                    debugPrint('PER-HOUSE FAIL DETAIL: ${r['details']}');
                  },
                ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingHouses = false);
    }
  }

  /// Calls [cosmicDailyManual] (asia-southeast2). User must be signed in; SDK sends ID token.
  Future<void> _runCosmicDaily() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final r = await _skyService.triggerDailyRun(date: _selectedDate);
      if (!mounted) return;
      final ok = r['success'] == true;
      final count = r['predictionsCount'];
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count != null
                  ? 'Analysis ready ($count predictions).'
                  : 'Analysis ready.',
            ),
          ),
        );
        setState(() => _refreshNonce++);
      } else {
        final err = r['error']?.toString() ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
            icon: _generating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 22),
            onPressed: _generating ? null : _runCosmicDaily,
            tooltip: 'Run cosmic analysis for this date',
          ),
          IconButton(
            icon: _generatingHouses
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.home_work_outlined, size: 22),
            onPressed: _generatingHouses ? null : _runPerHouse,
            tooltip: 'Force-regenerate per-house biweekly readings',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _showDatePicker,
            tooltip: 'Pick date',
          ),
        ],
      ),
      body: _selectedDate == _todayKey()
          ? _buildStreamBody(isDark)
          : _buildFutureBody(isDark),
    );
  }

  /// Realtime stream for today's data.
  Widget _buildStreamBody(bool isDark) {
    return StreamBuilder<CosmicDailyOutput?>(
      stream: _skyService.streamDailyOutput(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final output = snapshot.data;
        if (output == null) {
          return _buildEmptyState(isDark);
        }
        return _buildContent(output, isDark);
      },
    );
  }

  /// One-time fetch for historical dates.
  Widget _buildFutureBody(bool isDark) {
    return FutureBuilder<CosmicDailyOutput?>(
      key: ValueKey<String>('$_selectedDate-$_refreshNonce'),
      future: _skyService.getDailyOutput(_selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final output = snapshot.data;
        if (output == null) {
          return _buildEmptyState(isDark);
        }
        return _buildContent(output, isDark);
      },
    );
  }

  Widget _buildContent(CosmicDailyOutput output, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          _buildDateHeader(isDark),
          const SizedBox(height: 16),

          // World Energy
          _buildWorldEnergy(output.worldEnergy, isDark),
          const SizedBox(height: 24),

          // Top Signals
          if (output.signals.isNotEmpty) ...[
            _buildSectionHeader('Sky Signals', Icons.auto_awesome, isDark),
            const SizedBox(height: 8),
            _buildSignalChips(output.signals, isDark),
            const SizedBox(height: 24),
          ],

          // Predictions
          if (output.predictions.isNotEmpty) ...[
            _buildSectionHeader('Predictions', Icons.psychology, isDark),
            const SizedBox(height: 8),
            ...output.predictions.map((p) => _buildPredictionCard(p, isDark)),
            const SizedBox(height: 24),
          ],

          // Mundane Houses
          _buildSectionHeader('World Houses', Icons.public, isDark),
          const SizedBox(height: 8),
          _buildHouseGrid(output.houses, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WORLD ENERGY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWorldEnergy(String energy, bool isDark) {
    if (energy.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.indigo.withValues(alpha: 0.15), Colors.purple.withValues(alpha: 0.1)]
              : [Colors.indigo.withValues(alpha: 0.06), Colors.purple.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waves, size: 16,
                  color: isDark ? Colors.indigoAccent : Colors.indigo),
              const SizedBox(width: 6),
              Text(
                'World Energy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.indigoAccent : Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            energy,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIGNAL CHIPS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSignalChips(List<SignalSummary> signals, bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: signals.take(8).map((s) {
        final color = _signalColor(s);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${s.intensity}',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                s.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PREDICTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPredictionCard(CosmicPrediction prediction, bool isDark) {
    final confColor = prediction.confidence >= 0.7
        ? Colors.green
        : prediction.confidence >= 0.4
            ? Colors.amber
            : Colors.grey;

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
            Text(
              prediction.claim,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Wrap (not Row) so chips flow to next line on narrow widths
            // instead of overflowing on the right by 30px / 6.5px.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip(prediction.timeframe, isDark),
                _chip(prediction.confidenceLabel, isDark, color: confColor),
                ...prediction.domains.take(2).map((d) => _chip(d, isDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOUSE GRID — 12 mundane houses
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHouseGrid(Map<int, MundaneHouse> houses, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final houseNum = index + 1;
        final house = houses[houseNum];
        if (house == null) {
          return const SizedBox();
        }
        return _buildHouseTile(house, isDark);
      },
    );
  }

  Widget _buildHouseTile(MundaneHouse house, bool isDark) {
    final color = _houseColor(house.number);

    return GestureDetector(
      onTap: () => _showHouseSheet(house),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: house.hasPlanets
              ? color.withValues(alpha: 0.1)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: house.hasPlanets ? color.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'H${house.number}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: house.hasPlanets ? color : (isDark ? Colors.white30 : Colors.black26),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              house.name,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              house.sign,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black26),
            ),
            if (house.hasPlanets)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  house.planets.map((p) => _planetEmoji(p.planet)).join(' '),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOUSE DETAIL SHEET
  // ═══════════════════════════════════════════════════════════════════════════

  void _showHouseSheet(MundaneHouse house) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = _houseColor(house.number);

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
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'House ${house.number} — ${house.name}',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${house.sign} · ${house.domain}',
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                  const SizedBox(height: 16),

                  // Planets
                  if (house.hasPlanets) ...[
                    Text('Transiting Planets',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: house.planets.map((p) {
                        return Chip(
                          label: Text(
                            '${_planetEmoji(p.planet)} ${p.planet}${p.isRetro ? ' (R)' : ''} ${p.degree.toStringAsFixed(1)}°',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Reading
                  if (house.reading.isNotEmpty) ...[
                    Text('Reading',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    Text(
                      house.reading,
                      style: TextStyle(
                        fontSize: 14, height: 1.6,
                        color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.75),
                      ),
                    ),
                  ] else
                    Text(
                      'No reading available for this house today.',
                      style: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 13),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
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
            fontSize: 14, fontWeight: FontWeight.w500,
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
        Text(title, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        )),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nights_stay_outlined, size: 48,
                color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 16),
            Text(
              'No cosmic data for this date yet.\n'
              'Scheduled run: 2:30 AM UTC — or tap below to generate now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26, fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _runCosmicDaily,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(_generating ? 'Generating…' : 'Generate now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color ?? (isDark ? Colors.white54 : Colors.black45),
          fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      final key = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _selectedDate = key);
    }
  }

  Color _signalColor(SignalSummary s) {
    if (s.type == 'eclipse') return Colors.redAccent;
    if (s.dignity == 'debilitated') return Colors.redAccent;
    if (s.dignity == 'exalted') return Colors.greenAccent.shade700;
    if (s.aspect == 'trine' || s.aspect == 'sextile') return Colors.greenAccent.shade700;
    if (s.aspect == 'square' || s.aspect == 'opposition') return Colors.amber;
    if (s.type == 'station') return Colors.purpleAccent;
    return Colors.blueAccent;
  }

  Color _houseColor(int house) {
    if ([1, 4, 7, 10].contains(house)) return Colors.amber;       // Kendra
    if ([5, 9].contains(house)) return Colors.greenAccent.shade700; // Trikona
    if ([6, 8, 12].contains(house)) return Colors.redAccent;       // Dusthana
    if ([3, 11].contains(house)) return Colors.blueAccent;         // Upachaya
    return Colors.grey; // H2
  }

  String _planetEmoji(String planet) {
    const emojis = {
      'Sun': '☀️', 'Moon': '🌙', 'Mars': '♂️', 'Mercury': '☿️',
      'Jupiter': '♃', 'Venus': '♀️', 'Saturn': '♄', 'Rahu': '🐍',
      'Ketu': '🔥',
    };
    return emojis[planet] ?? '●';
  }
}
