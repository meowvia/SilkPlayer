import math
import os
from PIL import Image, ImageDraw, ImageFilter

SRC_PATH = '/Users/seoigor/.gemini/antigravity/brain/c9f85b98-7400-49da-bac1-fd33ba961f08/.user_uploaded/media_1791989844547_0879ff20.png'
OUT_DIR = '/Volumes/2T/SilkPlayer/Resources/Turntable'
BUILD_DIR = '/Volumes/2T/SilkPlayer/build'

pv_src_x = 839.0
pv_src_y = 152.0

CANVAS_SIZE = 750
HALF = CANVAS_SIZE / 2.0 # 375.0

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

# 1. Rear counterweight rod & cylinder
rod_end = pt(898, 76)
adraw.line([g_center, rod_end], fill=(215, 225, 238, 255), width=int(12 * SCALE))

# Counterweight cylinder (angled along 138°)
cw_pts = [pt(856, 114), pt(884, 52), pt(924, 72), pt(896, 134)]
adraw.polygon(cw_pts, fill=(230, 238, 248, 245))
adraw.polygon(cw_pts, outline=(255, 255, 255, 255), width=int(2.5 * SCALE))
for t in [0.25, 0.5, 0.75]:
    p1 = (cw_pts[0][0] * (1-t) + cw_pts[1][0] * t, cw_pts[0][1] * (1-t) + cw_pts[1][1] * t)
    p2 = (cw_pts[3][0] * (1-t) + cw_pts[2][0] * t, cw_pts[3][1] * (1-t) + cw_pts[2][1] * t)
    adraw.line([p1, p2], fill=(255, 255, 255, 220), width=int(2 * SCALE))

# 2. Gimbal Ring & Pivot Bearing
gr_out = 44 * SCALE
gr_in = 27 * SCALE
adraw.ellipse([g_center[0]-gr_out, g_center[1]-gr_out, g_center[0]+gr_out, g_center[1]+gr_out], fill=(215, 228, 242, 185))
adraw.ellipse([g_center[0]-gr_in, g_center[1]-gr_in, g_center[0]+gr_in, g_center[1]+gr_in], fill=(0, 0, 0, 0))
adraw.ellipse([g_center[0]-gr_out, g_center[1]-gr_out, g_center[0]+gr_out, g_center[1]+gr_out], outline=(255, 255, 255, 255), width=int(3 * SCALE))
adraw.ellipse([g_center[0]-gr_in, g_center[1]-gr_in, g_center[0]+gr_in, g_center[1]+gr_in], outline=(255, 255, 255, 200), width=int(2 * SCALE))

br_r = 13 * SCALE
adraw.ellipse([g_center[0]-br_r, g_center[1]-br_r, g_center[0]+br_r, g_center[1]+br_r], fill=(240, 245, 250, 255), outline=(150, 165, 180, 255), width=int(1.5 * SCALE))
adraw.ellipse([g_center[0]-br_r*0.5, g_center[1]-br_r*0.5, g_center[0]+br_r*0.5, g_center[1]+br_r*0.5], fill=(170, 182, 195, 255))

# 3. S-shaped Crystal Acrylic Tube
wand_points = [
    (839, 152), (826, 172), (810, 200), (794, 230), (778, 265),
    (764, 305), (752, 350), (738, 400), (718, 445), (693, 488),
    (662, 528), (626, 565), (587, 600), (550, 628), (524, 650)
]
w_pts = [pt(x, y) for x, y in wand_points]

for i in range(len(w_pts) - 1):
    adraw.line([w_pts[i], w_pts[i+1]], fill=(225, 238, 252, 95), width=int(24 * SCALE))
for p in w_pts:
    adraw.ellipse([p[0]-12*SCALE, p[1]-12*SCALE, p[0]+12*SCALE, p[1]+12*SCALE], fill=(225, 238, 252, 95))

for i in range(len(w_pts) - 1):
    adraw.line([w_pts[i], w_pts[i+1]], fill=(255, 255, 255, 125), width=int(26 * SCALE))

spec_pts = [(p[0] - 5 * SCALE, p[1] - 4 * SCALE) for p in w_pts]
for i in range(len(spec_pts) - 1):
    adraw.line([spec_pts[i], spec_pts[i+1]], fill=(255, 255, 255, 245), width=int(6 * SCALE))

rim_pts = [(p[0] + 5 * SCALE, p[1] + 4 * SCALE) for p in w_pts]
for i in range(len(rim_pts) - 1):
    adraw.line([rim_pts[i], rim_pts[i+1]], fill=(195, 220, 250, 165), width=int(4 * SCALE))

# 4. Headshell & Stylus Cartridge Assembly (Refined luxury crystal styling)
# Smoothly aligned with the end of the wand at (524, 650)
head_poly = [
    pt(548, 625), pt(568, 638), pt(528, 695), pt(492, 668), pt(512, 630)
]
adraw.polygon(head_poly, fill=(225, 238, 252, 200))
adraw.polygon(head_poly, outline=(255, 255, 255, 255), width=int(2.5 * SCALE))

# Cartridge body (sleek white body with chamfer)
cart_poly = [
    pt(536, 646), pt(554, 658), pt(524, 696), pt(506, 684)
]
adraw.polygon(cart_poly, fill=(248, 250, 254, 255))
adraw.polygon(cart_poly, outline=(175, 188, 200, 255), width=int(1.5 * SCALE))

# Cantilever & Diamond Stylus
adraw.line([pt(518, 690), pt(508, 702)], fill=(235, 242, 250, 255), width=int(3 * SCALE))
adraw.ellipse([pt(508, 702)[0]-2.5*SCALE, pt(508, 702)[1]-2.5*SCALE, pt(508, 702)[0]+2.5*SCALE, pt(508, 702)[1]+2.5*SCALE], fill=(255, 255, 255, 255))

# Ergonomic finger lift lever
adraw.line([pt(514, 680), pt(492, 704)], fill=(245, 248, 252, 255), width=int(3.5 * SCALE))
adraw.line([pt(492, 704), pt(478, 696)], fill=(245, 248, 252, 255), width=int(3.5 * SCALE))

tonearm_clean = arm_hi.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
arm_path = os.path.join(OUT_DIR, 'turntable_tonearm.png')
tonearm_clean.save(arm_path)
print(f"Saved refined crystal tonearm to {arm_path}")

