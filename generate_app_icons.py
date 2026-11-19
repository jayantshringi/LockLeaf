import os
import re
import subprocess
from PIL import Image, ImageDraw

def render_svg_to_png(chrome_path, html_content, output_png, width=512, height=512):
    temp_html = os.path.abspath('temp_render.html')
    abs_output = os.path.abspath(output_png)
    
    with open(temp_html, 'w', encoding='utf-8') as f:
        f.write(html_content)
        
    cmd = [
        chrome_path,
        '--headless=new',
        '--disable-gpu',
        f'--screenshot={abs_output}',
        f'--window-size={width},{height}',
        '--default-background-color=00000000',
        temp_html
    ]
    subprocess.run(cmd, check=True)
    if os.path.exists(temp_html):
        os.remove(temp_html)

def make_round_icon(im):
    size = im.size
    mask = Image.new('L', size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size[0], size[1]), fill=255)
    
    output = Image.new('RGBA', size, (0, 0, 0, 0))
    output.paste(im, (0, 0))
    output.putalpha(mask)
    return output

def main():
    chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
    svg_path = 'assets/lockleaf-icon.svg'
    
    with open(svg_path, 'r', encoding='utf-8') as f:
        svg_content = f.read()

    # Clean metadata from SVG
    svg_clean = re.sub(r'<metadata>.*?</metadata>', '', svg_content, flags=re.DOTALL)
    
    # 1. Full Icon HTML (with #06100C background)
    html_full = f"""<!DOCTYPE html>
<html>
<head>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: 512px; height: 512px; overflow: hidden; background: transparent; }}
  svg {{ width: 512px; height: 512px; display: block; }}
</style>
</head>
<body>
{svg_clean}
</body>
</html>"""
    
    master_png = 'assets/lockleaf-icon.png'
    print(f"Rendering master icon from SVG to {master_png}...")
    render_svg_to_png(chrome, html_full, master_png, 512, 512)
    
    # 2. Foreground-only HTML (strip <rect fill="#06100C"/> so background is 100% transparent)
    svg_fg = re.sub(r'<rect[^>]*fill="#06100C"[^>]*/>', '', svg_clean)
    html_fg = f"""<!DOCTYPE html>
<html>
<head>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: 512px; height: 512px; overflow: hidden; background: transparent; }}
  svg {{ width: 512px; height: 512px; display: block; }}
</style>
</head>
<body>
{svg_fg}
</body>
</html>"""
    
    fg_master_png = 'assets/temp_fg_master.png'
    print("Rendering adaptive foreground from SVG...")
    render_svg_to_png(chrome, html_fg, fg_master_png, 512, 512)
    
    # Load rendered master images
    img_full = Image.open(master_png).convert('RGBA')
    img_round = make_round_icon(img_full)
    img_fg = Image.open(fg_master_png).convert('RGBA')
    
    # Android icon density sizes: (legacy_size, foreground_size)
    densities = {
        'mipmap-mdpi': (48, 108),
        'mipmap-hdpi': (72, 162),
        'mipmap-xhdpi': (96, 216),
        'mipmap-xxhdpi': (144, 324),
        'mipmap-xxxhdpi': (192, 432),
    }
    
    res_base = 'android/app/src/main/res'
    
    for folder, (size, fg_size) in densities.items():
        dir_path = os.path.join(res_base, folder)
        os.makedirs(dir_path, exist_ok=True)
        
        # 1. Standard square/rounded legacy icon
        im_sized = img_full.resize((size, size), Image.Resampling.LANCZOS)
        out_square = os.path.join(dir_path, 'ic_launcher.png')
        im_sized.save(out_square, 'PNG')
        
        # 2. Round legacy icon
        im_round_sized = img_round.resize((size, size), Image.Resampling.LANCZOS)
        out_round = os.path.join(dir_path, 'ic_launcher_round.png')
        im_round_sized.save(out_round, 'PNG')
        
        # 3. Adaptive foreground icon
        im_fg_sized = img_fg.resize((fg_size, fg_size), Image.Resampling.LANCZOS)
        out_fg = os.path.join(dir_path, 'ic_launcher_foreground.png')
        im_fg_sized.save(out_fg, 'PNG')
        
        print(f"Generated {folder}: {size}x{size} square/round, {fg_size}x{fg_size} foreground")

    # Clean up temporary foreground master
    img_full.close()
    img_round.close()
    img_fg.close()
    if os.path.exists(fg_master_png):
        os.remove(fg_master_png)
        
    # Update background drawable to #06100C matching the SVG background
    bg_xml_path = os.path.join(res_base, 'drawable', 'ic_launcher_background.xml')
    bg_xml_content = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#06100C"
        android:pathData="M0,0h108v108h-108z"/>
</vector>
"""
    with open(bg_xml_path, 'w', encoding='utf-8') as f:
        f.write(bg_xml_content)
    print("Updated ic_launcher_background.xml to #06100C")
    
    # Update adaptive launcher xmls to reference @mipmap/ic_launcher_foreground
    anydpi_dir = os.path.join(res_base, 'mipmap-anydpi-v26')
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi_dir, 'ic_launcher_round.xml'), 'w', encoding='utf-8') as f:
        f.write(adaptive_xml)
    print("Updated adaptive icon XMLs to reference @mipmap/ic_launcher_foreground")
    print("All Android launcher icons successfully generated from assets/lockleaf-icon.svg!")

if __name__ == '__main__':
    main()
