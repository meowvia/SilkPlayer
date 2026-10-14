import math
import os
from PIL import Image, ImageDraw, ImageFilter

SRC_PATH = '/Users/seoigor/.gemini/antigravity/brain/c9f85b98-7400-49da-bac1-fd33ba961f08/.user_uploaded/media_1791989844547_0879ff20.png'
OUT_DIR = '/Volumes/2T/SilkPlayer/Resources/Turntable'
BUILD_DIR = '/Volumes/2T/SilkPlayer/build'
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(BUILD_DIR, exist_ok=True)

# Reference Plinth coordinates: 1024 x 800
# Platter Center: (412.0, 381.5), R_vinyl = 370.0, R_gold = 120.0
# Gimbal Pivot: (839.0, 152.0)
pv_src_x = 839.0
pv_src_y = 152.0

# Pivot-centered canvas size: 900 x 900
CANVAS_SIZE = 900
HALF = CANVAS_SIZE / 2.0 # 450.0

SCALE = 4
sw = CANVAS_SIZE * SCALE
sh = CANVAS_SIZE * SCALE
arm_hi = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
adraw = ImageDraw.Draw(arm_hi)

def pt(x, y):
    dx = x - pv_src_x
    dy = y - pv_src_y
    return ((HALF + dx) * SCALE, (HALF + dy) * SCALE)

g_center = (HALF * SCALE, HALF * SCALE)

# ==============================================================================
# 1. COUNTERWEIGHT & REAR STUB (Machined Brushed Steel / Anodized Titanium)
# ==============================================================================
# Rear shaft extending to (898, 76) along angle ~138°
rod_end = pt(906, 68)
adraw.line([g_center, rod_end], fill=(180, 190, 205, 255), width=int(14 * SCALE))
adraw.line([g_center, rod_end], fill=(240, 248, 255, 255), width=int(5 * SCALE))

# Counterweight cylinder (centered around 890, 84)
cw_pts = [pt(856, 114), pt(884, 48), pt(928, 70), pt(900, 136)]
# Base metallic fill
adraw.polygon(cw_pts, fill=(60, 68, 80, 255))
adraw.polygon(cw_pts, outline=(220, 230, 245, 255), width=int(2.5 * SCALE))

# Knurled grip grooves on counterweight
for t in [0.20, 0.35, 0.50, 0.65, 0.80]:
    p1 = (cw_pts[0][0] * (1-t) + cw_pts[1][0] * t, cw_pts[0][1] * (1-t) + cw_pts[1][1] * t)
    p2 = (cw_pts[3][0] * (1-t) + cw_pts[2][0] * t, cw_pts[3][1] * (1-t) + cw_pts[2][1] * t)
    adraw.line([p1, p2], fill=(210, 225, 240, 220), width=int(2 * SCALE))

# Rear weight calibration ring (champagne gold accent ring)
p_gold1 = (cw_pts[0][0] * 0.88 + cw_pts[1][0] * 0.12, cw_pts[0][1] * 0.88 + cw_pts[1][1] * 0.12)
p_gold2 = (cw_pts[3][0] * 0.88 + cw_pts[2][0] * 0.12, cw_pts[3][1] * 0.88 + cw_pts[2][1] * 0.12)
adraw.line([p_gold1, p_gold2], fill=(225, 195, 110, 255), width=int(4 * SCALE))

# ==============================================================================
# 2. GIMBAL BEARING ASSEMBLY (Precision Dual-Axis Chrome Gimbal)
# ==============================================================================
# Outer Gimbal Ring (matte slate titanium)
gr_out = 46 * SCALE
gr_in = 28 * SCALE
adraw.ellipse([g_center[0]-gr_out, g_center[1]-gr_out, g_center[0]+gr_out, g_center[1]+gr_out], fill=(45, 52, 64, 255))
adraw.ellipse([g_center[0]-gr_in, g_center[1]-gr_in, g_center[0]+gr_in, g_center[1]+gr_in], fill=(0, 0, 0, 0))
adraw.ellipse([g_center[0]-gr_out, g_center[1]-gr_out, g_center[0]+gr_out, g_center[1]+gr_out], outline=(200, 215, 230, 255), width=int(2.5 * SCALE))
adraw.ellipse([g_center[0]-gr_in, g_center[1]-gr_in, g_center[0]+gr_in, g_center[1]+gr_in], outline=(140, 155, 175, 255), width=int(2 * SCALE))

# Pivot vertical column & high-precision silver bearing cap
br_r = 15 * SCALE
adraw.ellipse([g_center[0]-br_r, g_center[1]-br_r, g_center[0]+br_r, g_center[1]+br_r], fill=(220, 230, 240, 255))
adraw.ellipse([g_center[0]-br_r, g_center[1]-br_r, g_center[0]+br_r, g_center[1]+br_r], outline=(255, 255, 255, 255), width=int(2 * SCALE))
# Center jewel bearing screw
adraw.ellipse([g_center[0]-br_r*0.45, g_center[1]-br_r*0.45, g_center[0]+br_r*0.45, g_center[1]+br_r*0.45], fill=(30, 35, 45, 255))

# ==============================================================================
# 3. S-CURVED AIRCRAFT ALUMINUM WAND (Polished Brushed Silver / Chrome)
# ==============================================================================
wand_points = [
    (839, 152),
    (824, 175),
    (804, 208),
    (784, 246),
    (766, 290),
    (748, 338),
    (728, 386),
    (700, 430),
    (664, 466),
    (628, 490),
    (610, 498)
]
w_pts = [pt(x, y) for x, y in wand_points]

# 1. Base solid aluminum core (brushed silver shadow)
for i in range(len(w_pts) - 1):
    adraw.line([w_pts[i], w_pts[i+1]], fill=(140, 152, 168, 255), width=int(22 * SCALE))
for p in w_pts:
    adraw.ellipse([p[0]-11*SCALE, p[1]-11*SCALE, p[0]+11*SCALE, p[1]+11*SCALE], fill=(140, 152, 168, 255))

# 2. Main cylindrical body gradient (neutral silver)
for i in range(len(w_pts) - 1):
    adraw.line([w_pts[i], w_pts[i+1]], fill=(210, 222, 236, 255), width=int(18 * SCALE))
for p in w_pts:
    adraw.ellipse([p[0]-9*SCALE, p[1]-9*SCALE, p[0]+9*SCALE, p[1]+9*SCALE], fill=(210, 222, 236, 255))

# 3. Razor-sharp top ridge specular highlight (bright chrome shine)
spec_pts = [(p[0] - 4 * SCALE, p[1] - 3 * SCALE) for p in w_pts]
for i in range(len(spec_pts) - 1):
    adraw.line([spec_pts[i], spec_pts[i+1]], fill=(255, 255, 255, 255), width=int(5 * SCALE))

# 4. Underside ambient rim light
rim_pts = [(p[0] + 4 * SCALE, p[1] + 3 * SCALE) for p in w_pts]
for i in range(len(rim_pts) - 1):
    adraw.line([rim_pts[i], rim_pts[i+1]], fill=(160, 175, 195, 255), width=int(3 * SCALE))

# Collar connector ring at headshell coupling (machined silver coupling nut)
c_pt = w_pts[-1]
adraw.ellipse([c_pt[0]-14*SCALE, c_pt[1]-14*SCALE, c_pt[0]+14*SCALE, c_pt[1]+14*SCALE], fill=(235, 242, 250, 255))
adraw.ellipse([c_pt[0]-14*SCALE, c_pt[1]-14*SCALE, c_pt[0]+14*SCALE, c_pt[1]+14*SCALE], outline=(100, 115, 130, 255), width=int(2 * SCALE))

# ==============================================================================
# 4. AUDIOPHILE HEADSHELL, CARTRIDGE & DIAMOND STYLUS (唱头与唱针)
# ==============================================================================
# Headshell geometry:
# Rectangular angled audiophile headshell (SME type)
# Body corners:
h_back_top = pt(618, 492)
h_back_bot = pt(626, 506)
h_front_bot = pt(514, 560)
h_front_top = pt(496, 542)

head_poly = [h_back_top, h_back_bot, h_front_bot, h_front_top]
# Solid deep anodized obsidian/matte black headshell block
adraw.polygon(head_poly, fill=(28, 32, 40, 255))
# Beveled silver chamfer outline around headshell
adraw.polygon(head_poly, outline=(225, 235, 245, 255), width=int(3 * SCALE))

# Top-side weight-relief slots (two iconic elongated oval slots on top of headshell)
slot1_a = pt(575, 508)
slot1_b = pt(545, 522)
adraw.line([slot1_a, slot1_b], fill=(15, 18, 22, 255), width=int(5 * SCALE))
adraw.line([slot1_a, slot1_b], fill=(80, 95, 115, 255), width=int(1.5 * SCALE))

slot2_a = pt(588, 515)
slot2_b = pt(558, 529)
adraw.line([slot2_a, slot2_b], fill=(15, 18, 22, 255), width=int(5 * SCALE))
adraw.line([slot2_a, slot2_b], fill=(80, 95, 115, 255), width=int(1.5 * SCALE))

# Cartridge Body (mounted underneath headshell - Ortofon Red / Audiophile Ruby accent)
cart_pts = [
    pt(548, 544),
    pt(554, 554),
    pt(512, 574),
    pt(500, 560)
]
adraw.polygon(cart_pts, fill=(220, 45, 55, 255)) # Luxury audiophile red cartridge body
adraw.polygon(cart_pts, outline=(255, 215, 215, 255), width=int(2 * SCALE))

# Chrome Needle Cantilever (extends forward-down from cartridge)
needle_root = pt(508, 565)
needle_tip = pt(492, 576) # The actual diamond stylus contact point!
adraw.line([needle_root, needle_tip], fill=(230, 240, 250, 255), width=int(5 * SCALE))
adraw.line([needle_root, needle_tip], fill=(255, 255, 255, 255), width=int(2 * SCALE))

# Diamond Stylus Tip (high-contrast sparkling diamond needle point)
adraw.ellipse([needle_tip[0]-5*SCALE, needle_tip[1]-5*SCALE, needle_tip[0]+5*SCALE, needle_tip[1]+5*SCALE], fill=(255, 255, 255, 255))
adraw.ellipse([needle_tip[0]-8*SCALE, needle_tip[1]-8*SCALE, needle_tip[0]+8*SCALE, needle_tip[1]+8*SCALE], outline=(150, 220, 255, 220), width=int(2 * SCALE))

# Ergonomic Chrome Finger-Lift Lever (extends curving from headshell right side)
lift_p1 = pt(554, 538)
lift_p2 = pt(580, 572)
lift_p3 = pt(600, 584)
adraw.line([lift_p1, lift_p2], fill=(235, 245, 255, 255), width=int(6 * SCALE))
adraw.line([lift_p2, lift_p3], fill=(235, 245, 255, 255), width=int(6 * SCALE))
adraw.ellipse([lift_p3[0]-4*SCALE, lift_p3[1]-4*SCALE, lift_p3[0]+4*SCALE, lift_p3[1]+4*SCALE], fill=(255, 255, 255, 255))

# High-contrast specular shine on headshell top edge
adraw.line([h_front_top, h_back_top], fill=(255, 255, 255, 255), width=int(3 * SCALE))

# Downsample to target size with Lanczos
tonearm_clean = arm_hi.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
arm_path = os.path.join(OUT_DIR, 'turntable_tonearm.png')
tonearm_clean.save(arm_path)
tonearm_clean.save('/Volumes/2T/SilkPlayer/build/audiophile_metal_tonearm.png')
print(f"Saved audiophile tonearm to {arm_path}, size: {tonearm_clean.size}")

# ==============================================================================
# 5. KINEMATICS CALIBRATION & COMPOSITE VERIFICATION
# ==============================================================================
# Stylus diamond tip is at (492, 576) in plinth coordinates
ndx = 492.0 - pv_src_x # -347.0
ndy = 576.0 - pv_src_y # +424.0
arm_rad = math.hypot(ndx, ndy)
base_angle = math.atan2(ndy, ndx)
print(f"Arm length: {arm_rad:.1f} px, Base angle: {math.degrees(base_angle):.1f}°")

# Target Lead-in (0% start of song): Stylus at R ≈ 355 px (outer vinyl groove)
# Target Run-out (100% end of song): Stylus at R ≈ 148 px (inner groove, outside gold disc R=120)
# Target Cradle (paused at 0:00): Stylus at R ≈ 435 px (parked on cradle outside platter)
for ang in [-30.0, -22.0, -18.0, -10.0, 0.0, 5.0, 8.0]:
    rad = base_angle + math.radians(ang)
    sx = pv_src_x + arm_rad * math.cos(rad)
    sy = pv_src_y + arm_rad * math.sin(rad)
    d = math.hypot(sx - 412.0, sy - 381.5)
    print(f"Angle {ang:+5.1f}°: Stylus pos ({sx:5.1f}, {sy:5.1f}), Dist: {d:5.1f} px (Gold: 120, Vinyl: 370)")

# Generate test composites at 0%, 50%, 100%, and cradle
plinth = Image.open(os.path.join(OUT_DIR, 'turntable_plinth.png'))
vinyl = Image.open(os.path.join(OUT_DIR, 'turntable_vinyl.png'))

test_angles = [
    (-28.0, "cradle_parked"),
    (-18.5, "lead_in_0pct"),
    (-5.0, "mid_track_50pct"),
    (8.0, "run_out_100pct")
]

for ang, label in test_angles:
    rot = tonearm_clean.rotate(-ang, resample=Image.Resampling.BICUBIC)
    comp = Image.new('RGBA', (1024, 800), (22, 24, 30, 255))
    comp.alpha_composite(plinth, (0, 0))
    comp.alpha_composite(vinyl, (12, int(381.5 - 400)))
    comp.alpha_composite(rot, (int(pv_src_x - HALF), int(pv_src_y - HALF)))
    out_file = os.path.join(BUILD_DIR, f"audiophile_test_{label}.png")
    comp.save(out_file)
    print(f"Saved {out_file}")

