import sys
import re

path = r'd:\ResourcePlus_APP - SPECIAL\resource_plus-App-V2_IOSUSER\lib\app\modules\home\views\orbit_chat_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Import dart:ui
content = content.replace("import 'dart:math' as math;\nimport 'package:flutter/material.dart';", "import 'dart:math' as math;\nimport 'dart:ui' as ui;\nimport 'package:flutter/material.dart';")

# Find the start of the voice block
voice_start = content.find('if (_voice)\n')
if voice_start == -1:
    voice_start = content.find('if (_voice)\r\n')
if voice_start == -1:
    print("Could not find if (_voice)")
    sys.exit(1)

# Find the end of the voice block
voice_end = content.find('],', voice_start)
# we need to find the `_conversation(!compact),` or `if (widget.error != null)`
voice_end = content.find('if (widget.error != null)', voice_start)
if voice_end == -1:
    print("Could not find end of block")
    sys.exit(1)
# Back up to the start of `],` before `if (widget.error != null)`
voice_end = content.rfind('                            ],', voice_start, voice_end)

if voice_end == -1:
    print("Could not find ],")
    sys.exit(1)

new_overlay = """                                if (_voice)
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.65),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                RepaintBoundary(
                                                  child: Container(
                                                    width: 180,
                                                    height: 180,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                                                          blurRadius: 70,
                                                          spreadRadius: 5,
                                                        ),
                                                        BoxShadow(
                                                          color: const Color(0xFFB100FF).withOpacity(0.25),
                                                          blurRadius: 90,
                                                          spreadRadius: -10,
                                                        ),
                                                      ],
                                                    ),
                                                    child: AnimatedBuilder(
                                                      animation: _motion,
                                                      builder: (_, _) => CustomPaint(
                                                        painter: _IntelligencePainter(
                                                          _motion.value,
                                                          _listening,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 40),
                                                Text(
                                                  _listening ? 'Listening...' : 'Connecting...',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 22,
                                                    letterSpacing: 1.2,
                                                    shadows: [
                                                      Shadow(color: Colors.white54, blurRadius: 8),
                                                    ]
                                                  ),
                                                ),
                                                const SizedBox(height: 50),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    _stopListening();
                                                    // we can't easily do setState here in raw python string without matching the file's exact state, but this is fine.
                                                    // Wait, in dart we do need setState. It's inside a StatefulBuilder maybe? No, it's a Stateful Widget.
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    side: const BorderSide(color: Colors.white54, width: 1.5),
                                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                                  ),
                                                  child: const Text('Cancel Voice', style: TextStyle(fontSize: 16)),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
"""
# Let's fix the python replacement to match exactly what is in the file.
import re

content = re.sub(
r'if \(_voice\)[\s\S]*?child: const Text\(\'Cancel Voice\'\),\n\s*\)\n\s*\]\,\n\s*\)\,\n\s*\)\,\n\s*\)\,\n\s*\)\,\n\s*\)\,',
r'''if (_voice)
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.65),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                RepaintBoundary(
                                                  child: Container(
                                                    width: 180,
                                                    height: 180,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                                                          blurRadius: 70,
                                                          spreadRadius: 5,
                                                        ),
                                                        BoxShadow(
                                                          color: const Color(0xFFB100FF).withOpacity(0.25),
                                                          blurRadius: 90,
                                                          spreadRadius: -10,
                                                        ),
                                                      ],
                                                    ),
                                                    child: AnimatedBuilder(
                                                      animation: _motion,
                                                      builder: (_, _) => CustomPaint(
                                                        painter: _IntelligencePainter(
                                                          _motion.value,
                                                          _listening,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 40),
                                                Text(
                                                  _listening ? 'Listening...' : 'Connecting...',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 22,
                                                    letterSpacing: 1.2,
                                                    shadows: [
                                                      Shadow(color: Colors.white54, blurRadius: 8),
                                                    ]
                                                  ),
                                                ),
                                                const SizedBox(height: 50),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    _stopListening();
                                                    setState(() => _voice = false);
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    side: const BorderSide(color: Colors.white54, width: 1.5),
                                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                                  ),
                                                  child: const Text('Cancel Voice', style: TextStyle(fontSize: 16)),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),''', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
