import re

path = r'd:/ResourcePlus_APP - SPECIAL/resource_plus-App-V2_IOSUSER/lib/app/modules/home/views/orbit_chat_screen.dart'
with open(path, encoding='utf-8') as f:
    content = f.read()

# Find the dead block: from "if (false)" to the closing "),"
# The unique marker is 'if (false)' followed by 'Positioned.fill'
# We'll replace from "if (false)" through the final "),\n                            ]," of the Stack

old_pattern = r'if \(false\)\s+Positioned\.fill\(\s+child: Container\([\s\S]+?\),\s+\),'
new_overlay = '''if (_voice)
                                _AiVoiceOverlay(
                                  motion: _motion,
                                  listening: _listening,
                                  onCancel: () {
                                    _stopListening();
                                    setState(() => _voice = false);
                                  },
                                ),'''

result = re.sub(old_pattern, new_overlay, content, count=1)
if result == content:
    print("ERROR: Pattern not matched!")
    # Debug: show what's around "if (false)"
    idx = content.find('if (false)')
    if idx >= 0:
        print("Found 'if (false)' at position", idx)
        print(repr(content[idx:idx+200]))
    else:
        print("'if (false)' not found in file!")
else:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(result)
    print("SUCCESS: File patched!")
