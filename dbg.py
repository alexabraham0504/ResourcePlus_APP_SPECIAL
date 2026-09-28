import re

path = r'd:\ResourcePlus_APP - SPECIAL\resource_plus-App-V2_IOSUSER\lib\app\modules\home\views\orbit_chat_screen.dart'
content = open(path, encoding='utf-8').read()

# Pattern: from "if (false)" up to and including the matching closing "),"
# The dead block starts with "if (false)" and ends with the closing of the Positioned.fill tree
# We'll find it by searching for "if (false)" followed by "Positioned.fill" and remove through the last "),"

old = re.search(r'(\s+if \(false\)\s+Positioned\.fill\([\s\S]+?\),\s+\],\s+\),\s+\),)', content)
if old:
    print("FOUND:", old.group()[:200])
else:
    # Try line-based approach
    lines = content.splitlines(keepends=True)
    
    # Find the line with "if (false)"
    start_i = None
    for i, line in enumerate(lines):
        if 'if (false)' in line:
            start_i = i
            break
    
    if start_i is None:
        print("NOT FOUND")
    else:
        print(f"Found 'if (false)' at line {start_i+1}")
        print(repr(lines[start_i]))
        # Print surrounding lines  
        for j in range(start_i-1, min(start_i+10, len(lines))):
            print(j+1, repr(lines[j]))
