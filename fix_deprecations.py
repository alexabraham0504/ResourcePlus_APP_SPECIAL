import os
import re

def fix_flutter_deprecations(directory):
    count_opacity = 0
    count_bg = 0
    count_on_bg = 0

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                original = content

                # Fix withOpacity(x) -> withValues(alpha: x)
                content, num_op = re.subn(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
                count_opacity += num_op
                
                # Fix colorScheme.background -> colorScheme.surface
                content, num_bg = re.subn(r'\.background\b', '.surface', content)
                count_bg += num_bg
                
                # Fix colorScheme.onBackground -> colorScheme.onSurface
                content, num_on_bg = re.subn(r'\.onBackground\b', '.onSurface', content)
                count_on_bg += num_on_bg

                if content != original:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)

    print(f"Fixed {count_opacity} withOpacity deprecations.")
    print(f"Fixed {count_bg} background deprecations.")
    print(f"Fixed {count_on_bg} onBackground deprecations.")

if __name__ == '__main__':
    fix_flutter_deprecations(r'd:\ResourcePlus_APP - SPECIAL\resource_plus-App-V2_IOSUSER\lib')
