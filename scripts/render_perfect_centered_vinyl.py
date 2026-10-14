import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = '/Volumes/2T/SilkPlayer/Resources/Turntable'
BUILD_DIR = '/Volumes/2T/SilkPlayer/build'

src_path = os.path.join(OUT_DIR, 'turntable_vinyl.png')
src = Image.open(src_path).convert('RGBA')

W, H = src.size # 800, 800
CX, CY = 400.0, 400.0

# 1. We keep the vinyl grooved disc outside r > 128
# Let's create an ultra-clean super-sampled center gold label
SCALE = 4
SW = W * SCALE
SH = H * SCALE
scx = CX * SCALE
scy = CY * SCALE

label_hi = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
ldraw = ImageDraw.Draw(label_hi)

# Label radius: 125 on 800px disc
R_LABEL = 125.0 * SCALE
R_RUNOUT = 138.0 * SCALE

# A. Lead-out black groove transition ring (between 125 and 138)
for r_step in range(int(R_LABEL), int(R_RUNOUT)):
    frac = (r_step - R_LABEL) / (R_RUNOUT - R_LABEL)
    col = int(12 + (1.0 - frac) * 15)
    ldraw.ellipse([scx - r_step, scy - r_step, scx + r_step, scy + r_step], outline=(col, col, col, 255), width=1)

# Subtle concentric run-out spiral lines
for r_spiral in [128.0 * SCALE, 132.0 * SCALE, 135.0 * SCALE]:
    ldraw.ellipse([scx - r_spiral, scy - r_spiral, scx + r_spiral, scy + r_spiral], outline=(30, 32, 38, 255), width=int(1.5 * SCALE))

# B. Champagne Gold Metallic Base with Anisotropic Reflections
# We create a 125-radius circular mask and apply radial/angular metallic sheen
base_gold = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
bdraw = ImageDraw.Draw(base_gold)

# Solid gold disc base
gold_box = [scx - R_LABEL, scy - R_LABEL, scx + R_LABEL, scy + R_LABEL]
bdraw.ellipse(gold_box, fill=(195, 160, 95, 255))

# Anisotropic brushed metal reflection (butterfly light sheen at 45 deg and 225 deg)
num_rays = 720
for i in range(num_rays):
    angle = (float(i) / num_rays) * 2.0 * math.pi
    # Intensity varies with cos(2 * angle - pi/2)
    intensity = 0.5 + 0.5 * math.cos(2.0 * angle - 0.5 * math.pi)
    # Highlight color: (240, 215, 145) to shadow (170, 135, 75)
    r = int(170 + intensity * 70)
    g = int(135 + intensity * 75)
    b = int(75  + intensity * 65)
    x2 = scx + math.cos(angle) * R_LABEL
    y2 = scy + math.sin(angle) * R_LABEL
    bdraw.line([(scx, scy), (x2, y2)], fill=(r, g, b, 180), width=int(2 * SCALE))

# Concentric micro-milling rings on gold label (fine pressed disc texture)
for r_ring in range(int(24 * SCALE), int(R_LABEL), int(2.5 * SCALE)):
    bdraw.ellipse([scx - r_ring, scy - r_ring, scx + r_ring, scy + r_ring], outline=(255, 240, 190, 45), width=1)

# Outer gold bevel ring
bdraw.ellipse(gold_box, outline=(255, 245, 205, 230), width=int(2.5 * SCALE))
bdraw.ellipse([scx - R_LABEL + 2*SCALE, scy - R_LABEL + 2*SCALE, scx + R_LABEL - 2*SCALE, scy + R_LABEL - 2*SCALE], outline=(150, 115, 60, 200), width=int(1.5 * SCALE))

# C. Audiophile Typographic & Geometric Ring Elements (Concentrically Symmetric)
# Concentric border rings inside label
r_inner_border = 108.0 * SCALE
bdraw.ellipse([scx - r_inner_border, scy - r_inner_border, scx + r_inner_border, scy + r_inner_border], outline=(140, 105, 55, 180), width=int(1.8 * SCALE))
bdraw.ellipse([scx - r_inner_border + 3*SCALE, scy - r_inner_border + 3*SCALE, scx + r_inner_border - 3*SCALE, scy + r_inner_border - 3*SCALE], outline=(255, 235, 180, 160), width=int(1.2 * SCALE))

# Middle ring
r_mid_border = 58.0 * SCALE
bdraw.ellipse([scx - r_mid_border, scy - r_mid_border, scx + r_mid_border, scy + r_mid_border], outline=(150, 115, 60, 150), width=int(1.5 * SCALE))

# D. SPINDLE HOLE & CENTER BEARING PIN (Strictly centered at 400.0, 400.0)
# Spindle hole outer radius = 22.0 * SCALE
r_spindle_rim = 22.0 * SCALE
bdraw.ellipse([scx - r_spindle_rim, scy - r_spindle_rim, scx + r_spindle_rim, scy + r_spindle_rim], fill=(225, 235, 248, 255), outline=(130, 145, 165, 255), width=int(2.0 * SCALE))

# Spindle hole depth shadow (inner hole r = 16.0 * SCALE)
r_hole = 16.0 * SCALE
bdraw.ellipse([scx - r_hole, scy - r_hole, scx + r_hole, scy + r_hole], fill=(8, 10, 14, 255))
# Top-left inner shadow in hole
bdraw.arc([scx - r_hole, scy - r_hole, scx + r_hole, scy + r_hole], start=135, end=315, fill=(0, 0, 0, 255), width=int(2.5 * SCALE))
bdraw.arc([scx - r_hole, scy - r_hole, scx + r_hole, scy + r_hole], start=-45, end=135, fill=(200, 215, 235, 200), width=int(1.5 * SCALE))

# Polished Stainless Steel Center Spindle Pin (r = 8.5 * SCALE)
r_pin = 8.5 * SCALE
bdraw.ellipse([scx - r_pin, scy - r_pin, scx + r_pin, scy + r_pin], fill=(210, 222, 236, 255), outline=(100, 115, 135, 255), width=int(1.2 * SCALE))
# Specular point highlight on chrome pin at (-2, -2)
pin_hl_x = scx - 2.5 * SCALE
pin_hl_y = scy - 2.5 * SCALE
bdraw.ellipse([pin_hl_x - 3.0*SCALE, pin_hl_y - 3.0*SCALE, pin_hl_x + 3.0*SCALE, pin_hl_y + 3.0*SCALE], fill=(255, 255, 255, 255))

# Composite label
label_hi = Image.alpha_composite(label_hi, base_gold)

# Downsample label with Lanczos to 800x800
label_clean = label_hi.resize((W, H), Image.Resampling.LANCZOS)

# 2. Composite over existing vinyl:
# We preserve the original vinyl outside r = 135
# Inside r <= 135, we smoothly blend to the new, mathematically centered gold label!
final_vinyl = src.copy()
final_pixels = final_vinyl.load()
label_pixels = label_clean.load()

for y in range(H):
    dy = y - CY
    for x in range(W):
        dx = x - CX
        dist = math.sqrt(dx*dx + dy*dy)
        if dist <= 126.0:
            final_pixels[x, y] = label_pixels[x, y]
        elif dist <= 138.0:
            # Blend smoothly across the run-out groove
            t = (dist - 126.0) / 12.0 # 0.0 at label edge, 1.0 at outer groove
            lp = label_pixels[x, y]
            vp = final_pixels[x, y]
            r = int(lp[0] * (1.0 - t) + vp[0] * t)
            g = int(lp[1] * (1.0 - t) + vp[1] * t)
            b = int(lp[2] * (1.0 - t) + vp[2] * t)
            a = int(lp[3] * (1.0 - t) + vp[3] * t)
            final_pixels[x, y] = (r, g, b, a)

final_vinyl.save(src_path)
print(f"Successfully saved perfectly centered vinyl to {src_path}")

# 3. VERIFY ROTATION STABILITY
# Rotate at 0, 90, 180, 270 and check center of spindle pin & label
for rot_angle in [0, 45, 90, 180]:
    rot = final_vinyl.rotate(rot_angle, resample=Image.Resampling.BICUBIC)
    rot_p = os.path.join(BUILD_DIR, f"verify_rot_{rot_angle}.png")
    rot.save(rot_p)
    print(f"Saved {rot_p}")

