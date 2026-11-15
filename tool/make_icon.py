from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

S = 1024
img = Image.new("RGB", (S, S), "#0B1020")
draw = ImageDraw.Draw(img)

# 深蓝渐变背景
for y in range(S):
    t = y / S
    r = int(11 + (26 - 11) * t)
    g = int(16 + (38 - 16) * t)
    b = int(32 + (72 - 32) * t)
    draw.line([(0, y), (S, y)], fill=(r, g, b))

# 中心柔光
glow = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([180, 180, 844, 844], fill=90)
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(Image.new("RGB", (S, S), "#1E3A5F"), img, glow)
draw = ImageDraw.Draw(img)

# 终端窗口
margin = 170
box = (margin, margin, S - margin, S - margin)
draw.rounded_rectangle(box, radius=96, fill="#0F172A", outline="#22D3EE", width=14)

# 窗口顶部三个点
colors = ["#F87171", "#FBBF24", "#34D399"]
for i, c in enumerate(colors):
    cx = margin + 78 + i * 52
    cy = margin + 66
    draw.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill=c)

# 提示符 >_
mono = "/System/Library/Fonts/Menlo.ttc"
font_prompt = ImageFont.truetype(mono, 300, index=0)
draw.text((margin + 90, margin + 190), ">_", font=font_prompt, fill="#22D3EE")

# 品牌字母 ss
font_brand = ImageFont.truetype(mono, 120, index=0)
draw.text((margin + 96, margin + 540), "ss", font=font_brand, fill="#E2E8F0")

# 右侧代码行装饰
for i in range(3):
    y = margin + 300 + i * 62
    w = 170 if i != 1 else 120
    draw.rounded_rectangle(
        (S - margin - 220, y, S - margin - 220 + w, y + 18),
        radius=9,
        fill="#334155" if i != 1 else "#334155",
    )

img.save("/tmp/ss-code-icon.png", "PNG")
print("saved /tmp/ss-code-icon.png", img.size)
