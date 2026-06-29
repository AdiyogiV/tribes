import re

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'r') as f:
    content = f.read()

# 1. Update Padding (Reserving space in the parent card)
padding_pattern = r'top:\s*48,\s*// Pushed down to give the moon plenty of sky room'
padding_replacement = r'top: 100, // Massive sky room reserved for the large moon'
content = re.sub(padding_pattern, padding_replacement, content)

# 2. Update Conduit (Connecting the Moon and Date Hub perfectly)
conduit_pattern = r'// 2\. The Energy Conduit \(Tether from Center to Moon\)\s*Positioned\(\s*top: 24,\s*child: Container\(\s*width: 1\.5,\s*height: \(total / 2\) - 50,'
conduit_replacement = r"""// 2. The Energy Conduit (Tether from Center to Moon)
                        Positioned(
                          top: -20,
                          child: Container(
                            width: 1.5,
                            height: (total / 2) - 10, // Reaches exactly from the moon to the Date Hub"""
content = re.sub(conduit_pattern, conduit_replacement, content)

# 3. Update Moon (Making it massive and placing it perfectly)
moon_pattern = r'// 4\. The Moon Phase \(Fixed at 12 o\'clock, showing dynamic phase\)\s*Positioned\(\s*top: -52, // Moved significantly higher up the conduit\s*child: Text\(\s*VedicTimeUtils\.getMoonPhaseEmoji\(_displayedDate\),\s*style: const TextStyle\(\s*fontSize: 28,'
moon_replacement = r"""// 4. The Moon Phase (Fixed at 12 o'clock, showing dynamic phase)
                        Positioned(
                          top: -70, // Moved up high into the reserved sky space
                          child: Text(
                            VedicTimeUtils.getMoonPhaseEmoji(_displayedDate),
                            style: const TextStyle(
                              fontSize: 48, // Much larger moon"""
content = re.sub(moon_pattern, moon_replacement, content)

with open('lib/features/astrology/presentation/widgets/nakshatra_ring_widget.dart', 'w') as f:
    f.write(content)

