import xml.etree.ElementTree as ET

ET.register_namespace('', "http://www.w3.org/2000/svg")
ET.register_namespace('xlink', "http://www.w3.org/1999/xlink")

tree = ET.parse('assets/images/logo.svg')
root = tree.getroot()

# The namespace is usually included in the tag name in ElementTree
namespace = '{http://www.w3.org/2000/svg}'
path_tag = f'{namespace}path'

def get_luminance(hex_color):
    hex_color = hex_color.lstrip('#')
    return sum(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

paths_to_remove = []
for child in root:
    if child.tag == path_tag:
        fill_color = child.get('fill')
        if fill_color and fill_color.startswith('#'):
            lum = get_luminance(fill_color)
            if lum < 100:  # Dark shadow/background artifacts
                paths_to_remove.append(child)

print(f"Removing {len(paths_to_remove)} dark background paths...")

for p in paths_to_remove:
    root.remove(p)

tree.write('assets/images/logo.svg', encoding='utf-8', xml_declaration=True)
print("Finished cleaning logo.svg")
