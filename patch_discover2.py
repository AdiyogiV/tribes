import sys

with open('lib/features/spaces/presentation/grams/grams_public_section.dart', 'r') as f:
    content = f.read()

old_divider = '''class GramsDiscoverDivider extends StatelessWidget {
  const GramsDiscoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        children: [
          Text(
            'DISCOVER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF666666) 
                  : const Color(0xFF999999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 0.5,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF222222) 
                  : const Color(0xFFE0E0E0),
            ),
          ),
        ],
      ),
    );
  }
}'''

new_divider = '''class GramsDiscoverDivider extends StatelessWidget {
  const GramsDiscoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        children: [
          Text(
            'DISCOVER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFFEEEEEE) 
                  : const Color(0xFF444444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF333333) 
                  : const Color(0xFFEEEEEE),
            ),
          ),
        ],
      ),
    );
  }
}'''

if old_divider in content:
    content = content.replace(old_divider, new_divider)
    with open('lib/features/spaces/presentation/grams/grams_public_section.dart', 'w') as f:
        f.write(content)
else:
    print("Could not find GramsDiscoverDivider")
