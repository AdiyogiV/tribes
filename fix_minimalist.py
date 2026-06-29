import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Replace left side (Labels)
old_left = """                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: rowColor,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subline,
                        style: TextStyle(
                          color: fgMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],"""

new_left = """                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: rowColor,
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subline,
                        style: TextStyle(
                          color: fgMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],"""

content = content.replace(old_left, new_left)

# Replace right side (Percentages)
old_right = """              // Right: Stacked Data (Today / Change)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cur%',
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftStr == '—' ? 'Baseline' : '$shiftStr shift',
                    style: TextStyle(
                      color: shiftColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),"""

new_right = """              // Right: Stacked Data (Today / Change)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cur%',
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftStr == '—' ? 'Baseline' : '$shiftStr shift',
                    style: TextStyle(
                      color: shiftColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),"""

content = content.replace(old_right, new_right)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
