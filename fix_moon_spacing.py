import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Add extra top padding to the wheelContent so the wheel physically shifts down
padding_target = r"""    final wheelContent = Padding\(
      padding: const EdgeInsets\.symmetric\(
        horizontal: AppDimensions\.paddingMd,
        vertical: AppDimensions\.paddingLg,
      \),
      child: wheel,
    \);"""

padding_replacement = r"""    final wheelContent = Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.paddingMd,
        right: AppDimensions.paddingMd,
        top: 48, // Pushed down to give the moon plenty of sky room
        bottom: 16,
      ),
      child: wheel,
    );"""
content = re.sub(padding_target, padding_replacement, content)

# 2. Push the moon further up
moon_target = r"""// 4\. The Moon Phase \(Fixed at 12 o'clock, showing dynamic phase\)\s*Positioned\(\s*top: -32,.*?child: Text\("""
moon_replacement = r"""// 4. The Moon Phase (Fixed at 12 o'clock, showing dynamic phase)
                        Positioned(
                          top: -52, // Moved significantly higher up the conduit
                          child: Text("""
content = re.sub(moon_target, moon_replacement, content, flags=re.DOTALL)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

