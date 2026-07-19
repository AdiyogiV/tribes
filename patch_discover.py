import sys

with open('lib/features/spaces/presentation/grams/grams_public_section.dart', 'r') as f:
    content = f.read()

old_divider = '''class GramsDiscoverDivider extends StatelessWidget {
  const GramsDiscoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GradientSeparator(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        ),
        Center(
          child: Text(
            'discover',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
      ],
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

if old_divider in content:
    content = content.replace(old_divider, new_divider)
    with open('lib/features/spaces/presentation/grams/grams_public_section.dart', 'w') as f:
        f.write(content)
else:
    print("Could not find GramsDiscoverDivider")
