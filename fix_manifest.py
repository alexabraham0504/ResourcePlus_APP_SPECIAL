import re
with open(r'android\app\src\main\AndroidManifest.xml', 'r') as f:
    c = f.read()
c = re.sub(r'android:largeHeap="true"\s*android:largeHeap="true"', 'android:largeHeap="true"', c)
with open(r'android\app\src\main\AndroidManifest.xml', 'w') as f:
    f.write(c)
