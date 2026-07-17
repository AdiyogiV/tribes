import re

with open('lib/features/baba/presentation/baba_overlay.dart', 'r') as f:
    content = f.read()

# Completely remove _buildLiveControls
content = re.sub(r'  Widget _buildLiveControls\(VoiceCallState state.*?\}\n\}\n', '}\n', content, flags=re.DOTALL)

with open('lib/features/baba/presentation/baba_overlay.dart', 'w') as f:
    f.write(content)
