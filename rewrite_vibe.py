import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

vibe_target = r"""    return Container\(
      width: double\.infinity,
      padding: const EdgeInsets\.all\(AppDimensions\.paddingLg\),
      child: Column\(
        crossAxisAlignment: CrossAxisAlignment\.start,
        mainAxisSize: MainAxisSize\.min,
        children: \[
          // Vibe label
          Text\(
            vibe\.label,
            style: TextStyle\(
              fontFamily: 'InstrumentSerif',
              fontSize: 32,
              fontWeight: FontWeight\.w400,
              color: c,
            \),
          \),
          const SizedBox\(height: 8\),
          // Subtitle and/or Action button row
          Row\(
            children: \[
              Expanded\(
                child: Text\(
                  subtitle,
                  style: TextStyle\(
                    fontSize: AppTheme\.holyCowTextSize - 1,
                    fontWeight: FontWeight\.w500,
                    letterSpacing: 0\.3,
                    color: c\.withValues\(alpha: 0\.65\),
                  \),
                \),
              \),"""

vibe_replacement = r"""    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingLg, 
        right: AppDimensions.paddingLg,
        bottom: AppDimensions.paddingLg,
        top: 8, // Tighter up to the wheel
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Elegant chic vibe label
          Text(
            vibe.label,
            style: TextStyle(
              fontFamily: 'InstrumentSerif',
              fontSize: 36, // Slightly larger, more confident
              fontWeight: FontWeight.w400,
              height: 1.1,
              color: c,
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle and/or Action button row
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle.toUpperCase(), // All caps makes it feel like an elegant label, not a sentence
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: c.withValues(alpha: 0.5), // Lighter to let the serif text pop
                  ),
                ),
              ),"""

content = re.sub(vibe_target, vibe_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

