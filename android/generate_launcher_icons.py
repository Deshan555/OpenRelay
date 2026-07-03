import os
import sys
import subprocess

# Auto-install Pillow if not available
try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow not found. Installing Pillow...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image, ImageDraw

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_PATH = os.path.join(BASE_DIR, "assets", "logo.png")
RES_DIR = os.path.join(BASE_DIR, "android", "app", "src", "main", "res")

if not os.path.exists(LOGO_PATH):
    print(f"Error: Logo file not found at {LOGO_PATH}")
    sys.exit(1)

# Sizes for ic_launcher (non-adaptive) and ic_launcher_round
MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Sizes for ic_launcher_foreground (adaptive)
FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

def create_circular_icon(img, size):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size, size), fill=255)
    
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
    output.paste(resized_img, (0, 0), mask=mask)
    return output

def create_adaptive_foreground(img, size):
    logo_size = (size * 2) // 3
    logo_resized = img.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    foreground = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - logo_size) // 2
    foreground.paste(logo_resized, (offset, offset))
    return foreground

def main():
    print(f"Loading logo from: {LOGO_PATH}")
    logo = Image.open(LOGO_PATH).convert("RGBA")
    
    w, h = logo.size
    if w != h:
        print("Warning: Logo is not square. Center-cropping to square...")
        min_dim = min(w, h)
        left = (w - min_dim) // 2
        top = (h - min_dim) // 2
        logo = logo.crop((left, top, left + min_dim, top + min_dim))

    # Generate icons for each mipmap directory
    for folder, size in MIPMAP_SIZES.items():
        folder_path = os.path.join(RES_DIR, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # 1. Standard ic_launcher.png
        launcher_img = logo.resize((size, size), Image.Resampling.LANCZOS)
        launcher_img.save(os.path.join(folder_path, "ic_launcher.png"), "PNG")
        print(f"Generated {folder}/ic_launcher.png ({size}x{size})")
        
        # 2. Round ic_launcher_round.png
        round_img = create_circular_icon(logo, size)
        round_img.save(os.path.join(folder_path, "ic_launcher_round.png"), "PNG")
        print(f"Generated {folder}/ic_launcher_round.png ({size}x{size})")
        
    for folder, size in FOREGROUND_SIZES.items():
        folder_path = os.path.join(RES_DIR, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # 3. Adaptive ic_launcher_foreground.png
        foreground_img = create_adaptive_foreground(logo, size)
        foreground_img.save(os.path.join(folder_path, "ic_launcher_foreground.png"), "PNG")
        print(f"Generated {folder}/ic_launcher_foreground.png ({size}x{size})")

    # 4. Generate values/colors.xml for background color
    values_dir = os.path.join(RES_DIR, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_path = os.path.join(values_dir, "colors.xml")
    
    if os.path.exists(colors_path):
        print(f"{colors_path} already exists. Appending or updating launcher background color...")
        with open(colors_path, "r") as f:
            content = f.read()
        if "ic_launcher_background" not in content:
            if "</resources>" in content:
                content = content.replace("</resources>", "    <color name=\"ic_launcher_background\">#FFFFFF</color>\n</resources>")
                with open(colors_path, "w") as f:
                    f.write(content)
    else:
        with open(colors_path, "w") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n')
    print("Configured values/colors.xml")

    # 5. Generate mipmap-anydpi-v26 XML configurations
    anydpi_dir = os.path.join(RES_DIR, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    
    launcher_xml_path = os.path.join(anydpi_dir, "ic_launcher.xml")
    with open(launcher_xml_path, "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')
    print("Generated mipmap-anydpi-v26/ic_launcher.xml")

    launcher_round_xml_path = os.path.join(anydpi_dir, "ic_launcher_round.xml")
    with open(launcher_round_xml_path, "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')
    print("Generated mipmap-anydpi-v26/ic_launcher_round.xml")
    
    print("Launcher icon generation completed successfully!")

if __name__ == "__main__":
    main()
