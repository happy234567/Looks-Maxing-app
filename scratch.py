import re
from collections import Counter

data = open('assets/images/logo.svg', 'r', encoding='utf-8', errors='ignore').read()
colors = re.findall(r'fill=\"(#[A-Fa-f0-9]{6})\"', data)

def luminance(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

for c, count in Counter(colors).most_common():
    rgb = luminance(c)
    print(f"{c}: {count} -> {rgb} Sum: {sum(rgb)}")
