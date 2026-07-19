import sys

with open('lib/app/tabs/grams.dart', 'r') as f:
    content = f.read()

start_marker = '        // User\'s own grams grouped with an elegant heading'
end_marker = '        // Public grams section below user\'s grams'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1:
    print("Could not find markers in grams.dart")
    sys.exit(1)

new_code = '''        // User's own grams grouped with an elegant heading
        if (sortedDocs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'YOUR GRAMS',
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
          ),
        Wrap(
          children:
              sortedDocs.map((document) => _buildGramItem(document)).toList(),
        ),
'''

with open('lib/app/tabs/grams.dart', 'w') as f:
    f.write(content[:start_idx] + new_code + content[end_idx:])
