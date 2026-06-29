import re

with open('lib/features/astrology/presentation/pages/holycow/widgets/holycow_secondary_cards.dart', 'r') as f:
    content = f.read()

# Rename the property
content = content.replace('final Widget? insertAfterSkyCard;', 'final Widget? insertBeforeSkyCard;')
content = content.replace('this.insertAfterSkyCard,', 'this.insertBeforeSkyCard,')

# Move the widget block
sky_card_start = r'// Current Sky with optional Birth Chart overlay\s*if \(loadingState\.isSkyLoaded\) \.\.\.\['

wheel_block = r"""        // Wheel \+ text-insight combo — injected directly BELOW the Current
        // Sky card on mobile\. When sky data hasn't loaded the sky block is
        // skipped and this slots in at the top instead\.
        if \(insertAfterSkyCard != null\) \.\.\.\[
          insertAfterSkyCard!,
          SizedBox\(height: spacing\),
        \],"""

# remove the old block
content = re.sub(wheel_block, '', content)

# insert the new block above the sky card
new_wheel_block = """        // Wheel + text-insight combo — injected directly ABOVE the Current Sky card on mobile.
        if (insertBeforeSkyCard != null) ...[
          insertBeforeSkyCard!,
          SizedBox(height: spacing),
        ],

        // Current Sky with optional Birth Chart overlay
        if (loadingState.isSkyLoaded) ...["""

content = re.sub(sky_card_start, new_wheel_block, content)

with open('lib/features/astrology/presentation/pages/holycow/widgets/holycow_secondary_cards.dart', 'w') as f:
    f.write(content)


with open('lib/features/astrology/presentation/pages/holycow/holycow_cosmic_content.dart', 'r') as f:
    content2 = f.read()

content2 = content2.replace('insertAfterSkyCard: isWide ? null : wheelWidget,', 'insertBeforeSkyCard: isWide ? null : wheelWidget,')

with open('lib/features/astrology/presentation/pages/holycow/holycow_cosmic_content.dart', 'w') as f:
    f.write(content2)

