import 'package:flutter/material.dart';
import 'package:aurogram/utils/astrology/dasha_utils.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Shows detailed information about a Dasha level in a bottom sheet
class DashaLevelDialog extends StatelessWidget {
  final Map<String, dynamic> level;
  final Map<String, dynamic>? dasha;
  final bool isDark;

  const DashaLevelDialog({
    super.key,
    required this.level,
    required this.dasha,
    required this.isDark,
  });

  static void show(BuildContext context, Map<String, dynamic> level,
      Map<String, dynamic>? dasha, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DashaLevelDialog(
        level: level,
        dasha: dasha,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periods = DashaUtils.extractPeriodsForLevel(
        level['key'] as String? ?? '', dasha);
    final dateRange = DashaUtils.formatDashaDateRange(
        level['startDate'] as String?, level['endDate'] as String?);
    final duration = DashaUtils.formatDurationLabel(
        level['startDate'] as String?, level['endDate'] as String?);

    final sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        top: 48,
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    level['icon'] as IconData? ?? Icons.bolt_rounded,
                    size: 30,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level['label'] as String? ?? 'Dasha',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level['lord'] as String? ?? '—',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          duration,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black54,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'PERIODS',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: periods.isEmpty
                  ? Center(
                      child: Text(
                        'Detailed periods for this level are not available yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: periods.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        height: 16,
                      ),
                      itemBuilder: (context, index) => _DashaPeriodTile(
                        period: periods[index],
                        isDark: isDark,
                        activeLord: level['lord'] as String?,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashaPeriodTile extends StatelessWidget {
  final Map<String, dynamic> period;
  final bool isDark;
  final String? activeLord;

  const _DashaPeriodTile({
    required this.period,
    required this.isDark,
    this.activeLord,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeLord != null &&
        period['lord']?.toString().toLowerCase() == activeLord!.toLowerCase();
    final range = DashaUtils.formatDashaDateRange(
        period['startDate'] as String?, period['endDate'] as String?);
    final duration = DashaUtils.formatDurationLabel(
        period['startDate'] as String?, period['endDate'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                period['lord'] as String? ?? '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          range,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.65),
          ),
        ),
        if (duration != null) ...[
          const SizedBox(height: 2),
          Text(
            duration,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}




