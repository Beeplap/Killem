import os
import numpy as np
from PIL import Image, ImageDraw

OUTPUT_DIR = "assets/textures"
os.makedirs(f"{OUTPUT_DIR}/deployables", exist_ok=True)
os.makedirs(f"{OUTPUT_DIR}/props", exist_ok=True)

# 1. Barbed Wire (64x32)
def make_barbed_wire():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Wooden/metallic support stakes
    d.rectangle([8, 6, 12, 28], fill=(60, 50, 45, 255), outline=(30, 25, 20, 255))
    d.rectangle([52, 6, 56, 28], fill=(60, 50, 45, 255), outline=(30, 25, 20, 255))
    # Coiled rusted razor strands
    for y in [10, 16, 22]:
        points = []
        for x in range(4, 60, 4):
            offset_y = y + (2 if (x // 4) % 2 == 0 else -2)
            points.append((x, offset_y))
        d.line(points, fill=(150, 140, 130, 240), width=2)
        # Barbs / spurs
        for bx in range(12, 52, 6):
            d.line([(bx - 2, y - 3), (bx + 2, y + 3)], fill=(200, 180, 160, 255), width=1)
            d.line([(bx + 2, y - 3), (bx - 2, y + 3)], fill=(180, 90, 40, 255), width=1)
    img.save(f"{OUTPUT_DIR}/deployables/barbed_wire.png")
    print("Saved barbed_wire.png")

# 2. Claymore Mine (32x24)
def make_claymore():
    img = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Metal legs
    d.line([(8, 14), (4, 22)], fill=(40, 45, 40, 255), width=2)
    d.line([(24, 14), (28, 22)], fill=(40, 45, 40, 255), width=2)
    # Curved explosive block (Olive Drab Green)
    d.rounded_rectangle([6, 6, 26, 16], radius=2, fill=(65, 80, 55, 255), outline=(35, 45, 30, 255))
    # Embossed 'FRONT TOWARD ENEMY' text / indicator stripe
    d.line([(9, 10), (23, 10)], fill=(180, 195, 140, 240), width=1)
    d.line([(9, 12), (23, 12)], fill=(180, 195, 140, 240), width=1)
    # Sensor / Blinking LED
    d.ellipse([14, 7, 18, 9], fill=(240, 40, 30, 255))
    img.save(f"{OUTPUT_DIR}/deployables/claymore_mine.png")
    print("Saved claymore_mine.png")

# 3. Sentry Turret (48x48)
def make_sentry():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Tripod legs
    d.line([(24, 28), (8, 42)], fill=(40, 42, 48, 255), width=3)
    d.line([(24, 28), (40, 42)], fill=(40, 42, 48, 255), width=3)
    d.line([(24, 28), (24, 44)], fill=(30, 32, 36, 255), width=3)
    # Swivel base
    d.ellipse([18, 22, 30, 32], fill=(60, 65, 75, 255), outline=(30, 32, 38, 255))
    # Turret body
    d.rounded_rectangle([14, 12, 34, 24], radius=3, fill=(80, 88, 100, 255), outline=(40, 45, 52, 255))
    # Dual barrels
    d.rectangle([34, 14, 44, 16], fill=(30, 30, 35, 255))
    d.rectangle([34, 20, 44, 22], fill=(30, 30, 35, 255))
    # Ammo drum
    d.ellipse([10, 14, 20, 22], fill=(120, 100, 40, 255), outline=(70, 60, 20, 255))
    # Cyan targeting sensor eye
    d.ellipse([26, 16, 30, 20], fill=(40, 220, 255, 255))
    img.save(f"{OUTPUT_DIR}/deployables/sentry_turret.png")
    print("Saved sentry_turret.png")

# 4. Acid Pool (64x64)
def make_acid_pool():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Glowing green organic puddle
    for r in range(28, 4, -4):
        alpha = int(90 + (28 - r) * 6)
        color = (40, 180 + r * 2, 30, alpha)
        d.ellipse([32 - r, 32 - int(r * 0.55), 32 + r, 32 + int(r * 0.55)], fill=color)
    # Bubbles
    for bx, by, br in [(22, 28, 3), (38, 34, 4), (30, 24, 2), (42, 28, 3), (20, 34, 2)]:
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(180, 255, 80, 220), outline=(220, 255, 140, 255))
    img.save(f"{OUTPUT_DIR}/props/acid_pool.png")
    print("Saved acid_pool.png")

# 5. Power Transformer Box (40x48)
def make_transformer():
    img = Image.new("RGBA", (40, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Industrial metal enclosure
    d.rounded_rectangle([4, 4, 36, 44], radius=2, fill=(70, 75, 82, 255), outline=(35, 38, 42, 255))
    # Cooling fins
    for y in range(10, 38, 5):
        d.line([(8, y), (32, y)], fill=(45, 48, 55, 255), width=2)
    # Yellow high voltage warning plate
    d.rectangle([14, 18, 26, 30], fill=(240, 200, 20, 255), outline=(30, 30, 30, 255))
    # Black lightning bolt
    d.polygon([(20, 19), (16, 25), (20, 25), (18, 29), (24, 23), (20, 23)], fill=(20, 20, 20, 255))
    # Spark terminals on top
    d.rectangle([10, 0, 14, 4], fill=(180, 160, 60, 255))
    d.rectangle([26, 0, 30, 4], fill=(180, 160, 60, 255))
    img.save(f"{OUTPUT_DIR}/props/power_transformer.png")
    print("Saved power_transformer.png")

# 6. Military Supply Crate (48x40)
def make_supply_crate():
    img = Image.new("RGBA", (48, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Heavy olive-drab steel crate
    d.rounded_rectangle([4, 6, 44, 36], radius=3, fill=(55, 68, 48, 255), outline=(25, 32, 22, 255))
    # Reinforced titanium corner braces
    d.rectangle([4, 6, 12, 14], fill=(35, 40, 32, 255))
    d.rectangle([36, 6, 44, 14], fill=(35, 40, 32, 255))
    d.rectangle([4, 28, 12, 36], fill=(35, 40, 32, 255))
    d.rectangle([36, 28, 44, 36], fill=(35, 40, 32, 255))
    # Yellow hazard stencil & white star
    d.line([(14, 8), (34, 8)], fill=(220, 180, 30, 240), width=2)
    d.line([(14, 34), (34, 34)], fill=(220, 180, 30, 240), width=2)
    # Stencil star in center
    d.ellipse([20, 17, 28, 25], fill=(230, 235, 240, 255))
    # Flashing beacon light on top
    d.ellipse([22, 2, 26, 6], fill=(255, 60, 40, 255))
    img.save(f"{OUTPUT_DIR}/props/supply_crate.png")
    print("Saved supply_crate.png")

make_barbed_wire()
make_claymore()
make_sentry()
make_acid_pool()
make_transformer()
make_supply_crate()
