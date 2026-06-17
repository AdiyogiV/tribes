#!/usr/bin/env python3
"""Aurogram — clean 4-slide pitch deck. Big vision, minimal noise."""
import zipfile

W, H, I = 9144000, 6858000, 914400
def em(x): return int(x * I)

BG    = "080C14"
GOLD  = "C9A96E"
WHITE = "FFFFFF"
DIM   = "4A5568"
CARD  = "0D1420"
WARM  = "5A3D34"

_sid = [2]
def sid():
    _sid[0] += 1
    return _sid[0]

def sp(x, y, cx, cy, fill, border_color=None, border_w=12700):
    bdr = f'<a:ln w="{border_w}"><a:solidFill><a:srgbClr val="{border_color}"/></a:solidFill></a:ln>' if border_color else '<a:ln><a:noFill/></a:ln>'
    return f'''<p:sp><p:nvSpPr><p:cNvPr id="{sid()}" name="s"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>{bdr}</p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>'''

def _run_xml(r):
    t = r["t"].replace("&", "&amp;").replace("<", "&lt;")
    sz = r.get("sz", 18) * 100
    b  = 1 if r.get("b") else 0
    iv = 1 if r.get("i") else 0
    c  = r.get("c", WHITE)
    return (f'<a:r><a:rPr lang="en-US" sz="{sz}" b="{b}" i="{iv}" dirty="0">'
            f'<a:solidFill><a:srgbClr val="{c}"/></a:solidFill>'
            f'<a:latin typeface="Segoe UI"/></a:rPr><a:t>{t}</a:t></a:r>')

def _para_xml(p):
    if p is None:
        return '<a:p/>'
    runs = ''.join(_run_xml(r) for r in p.get("runs", []))
    algn = p.get("align", "l")
    return f'<a:p><a:pPr algn="{algn}"/>{runs}</a:p>'

def tx(x, y, cx, cy, paras, anchor="t"):
    anc_map = {"t": "t", "m": "ctr", "b": "b"}
    body = ''.join(_para_xml(p) for p in paras)
    anc  = anc_map[anchor]
    i    = sid()
    return (f'<p:sp><p:nvSpPr><p:cNvPr id="{i}" name="t"/>'
            f'<p:cNvSpPr txBox="1"><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>'
            f'<p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>'
            f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
            f'<a:noFill/><a:ln><a:noFill/></a:ln></p:spPr>'
            f'<p:txBody><a:bodyPr wrap="sq" anchor="{anc}"><a:spAutoFit/></a:bodyPr>'
            f'<a:lstStyle/>{body}</p:txBody></p:sp>')

def R(t, sz=18, b=False, c=WHITE, i=False):
    return {"t": t, "sz": sz, "b": b, "c": c, "i": i}

def slide(shapes):
    _sid[0] = 2
    body = '\n'.join(shapes)
    return f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="{BG}"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      {body}
    </p:spTree>
  </p:cSld>
</p:sld>'''.encode()

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 1 — COVER: one sentence that says everything
# ─────────────────────────────────────────────────────────────────────────────
def s1():
    return slide([
        # Gold top bar
        sp(0, 0, W, em(0.06), GOLD),
        # Warm bottom bar
        sp(0, H - em(0.06), W, em(0.06), WARM),

        # Vertical gold accent line (left)
        sp(em(0.65), em(1.8), em(0.06), em(3.8), GOLD),

        # App name — huge
        tx(em(0.9), em(1.7), em(8.5), em(1.6),
           [{"align": "l", "runs": [R("AUROGRAM", 72, b=True, c=WHITE)]}]),

        # One-line pitch
        tx(em(0.9), em(3.2), em(7.5), em(0.9),
           [{"align": "l", "runs": [R("The social app built around who you are cosmically.", 26, c=GOLD)]}]),

        # Sub-description — two lines, restrained
        tx(em(0.9), em(4.15), em(7.2), em(1.2),
           [{"align": "l", "runs": [R("Community spaces · Vedic astrology · AI that knows your chart", 16, c=DIM)]},
            {"align": "l", "runs": [R("Real-time video · Stories · Anonymous voice — one cross-platform app.", 16, c=DIM)]}]),

        # Platform row
        tx(em(0.9), em(5.5), em(7), em(0.5),
           [{"align": "l", "runs": [R("iOS  ·  Android  ·  Web  ·  macOS  ·  Windows", 13, c=WARM)]}]),
    ])

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 2 — THE GAP: why this moment, why no one has done it
# ─────────────────────────────────────────────────────────────────────────────
def s2():
    return slide([
        sp(0, 0, W, em(0.06), GOLD),
        sp(0, H - em(0.06), W, em(0.06), WARM),

        # Section label
        tx(em(0.65), em(0.35), em(3), em(0.45),
           [{"align": "l", "runs": [R("THE OPPORTUNITY", 11, b=True, c=GOLD)]}]),

        # Big headline
        tx(em(0.65), em(0.9), em(8.5), em(1.1),
           [{"align": "l", "runs": [R("3.5 billion people follow astrology.", 34, b=True, c=WHITE)]},
            {"align": "l", "runs": [R("No social platform takes them seriously.", 34, b=True, c=GOLD)]}]),

        # Divider
        sp(em(0.65), em(2.15), em(8.7), em(0.04), DIM),

        # Three columns — sharp contrast pairs
        *_gap_col(em(0.65), em(2.45), "Co-Star\nPattern",   "Astrology only.\nNo community.\nNo real-time AI."),
        *_gap_col(em(3.55), em(2.45), "Discord\nReddit",    "Community only.\nNo cosmic layer.\nNo identity depth."),
        *_gap_col(em(6.45), em(2.45), "Instagram\nTikTok",  "Video only.\nAlgorithmic.\nNo meaning."),

        # The Aurogram answer — full width, bold
        sp(em(0.65), em(5.0), em(8.7), em(1.3), CARD),
        sp(em(0.65), em(5.0), em(0.07), em(1.3), GOLD),
        tx(em(0.9), em(5.05), em(8.2), em(1.2),
           [{"align": "l", "runs": [R("Aurogram is the first app that gives you all three —", 16, c=WHITE)]},
            {"align": "l", "runs": [R("social identity + cosmic self + real-time community.", 16, b=True, c=GOLD)]}],
           anchor="m"),
    ])

def _gap_col(x, y, name, desc):
    return [
        sp(x, y, em(2.6), em(2.3), CARD),
        sp(x, y, em(2.6), em(0.05), "2A3040"),
        tx(x + em(0.2), y + em(0.15), em(2.2), em(0.65),
           [{"align": "l", "runs": [R(name, 14, b=True, c=DIM)]}]),
        tx(x + em(0.2), y + em(0.75), em(2.2), em(1.4),
           [{"align": "l", "runs": [R(desc, 13, c="2A3040")]}]),  # intentionally muted — they lose
    ]

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 3 — WHAT'S BUILT: shipped, real, now
# ─────────────────────────────────────────────────────────────────────────────
def s3():
    return slide([
        sp(0, 0, W, em(0.06), GOLD),
        sp(0, H - em(0.06), W, em(0.06), WARM),

        tx(em(0.65), em(0.35), em(4), em(0.45),
           [{"align": "l", "runs": [R("WHAT'S BUILT TODAY", 11, b=True, c=GOLD)]}]),

        tx(em(0.65), em(0.9), em(8.5), em(0.85),
           [{"align": "l", "runs": [R("Not a prototype. A full-stack, cross-platform social app.", 30, b=True, c=WHITE)]}]),

        sp(em(0.65), em(1.85), em(8.7), em(0.04), DIM),

        # 4 big stat boxes top row
        *_stat(em(0.65), em(2.1), "5",      "platforms\nshipped", GOLD),
        *_stat(em(2.85), em(2.1), "22",     "cloud functions\nrunning live", "4A7FA5"),
        *_stat(em(5.05), em(2.1), "8 / 8",  "Vedic signal\ntypes live", "4E9A6F"),
        *_stat(em(7.25), em(2.1), "∞",      "Gemini AI\ncontext", WARM),

        # Feature list — 2 cols, clean
        *_feat_row(em(0.65), em(4.0),  "Feed, Stories & Rich Media"),
        *_feat_row(em(0.65), em(4.65), "Spaces — moderated community hubs"),
        *_feat_row(em(0.65), em(5.3),  "Anonymous confessions layer"),

        *_feat_row(em(4.85), em(4.0),  "Live video & voice calls (Agora)"),
        *_feat_row(em(4.85), em(4.65), "HolyCow AI — chart-aware Gemini bot"),
        *_feat_row(em(4.85), em(5.3),  "Daily Vedic astrology pipeline"),
    ])

def _stat(x, y, num, label, color):
    return [
        sp(x, y, em(1.95), em(1.7), CARD),
        sp(x, y, em(1.95), em(0.06), color),
        tx(x + em(0.15), y + em(0.12), em(1.65), em(0.8),
           [{"align": "l", "runs": [R(num, 34, b=True, c=color)]}]),
        tx(x + em(0.15), y + em(0.9), em(1.65), em(0.7),
           [{"align": "l", "runs": [R(label, 11, c=DIM)]}]),
    ]

def _feat_row(x, y, text):
    return [
        tx(x, y, em(4.0), em(0.5),
           [{"align": "l", "runs": [R("✓  ", 13, b=True, c=GOLD), R(text, 13, c=WHITE)]}]),
    ]

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 4 — THE BIG VISION + ASK
# ─────────────────────────────────────────────────────────────────────────────
def s4():
    return slide([
        sp(0, 0, W, em(0.06), GOLD),
        sp(0, H - em(0.06), W, em(0.06), WARM),

        tx(em(0.65), em(0.35), em(4), em(0.45),
           [{"align": "l", "runs": [R("THE VISION", 11, b=True, c=GOLD)]}]),

        # Left: the big bet
        tx(em(0.65), em(0.9), em(5.2), em(1.5),
           [{"align": "l", "runs": [R("Astrology is the next", 30, b=True, c=WHITE)]},
            {"align": "l", "runs": [R("personality graph.", 30, b=True, c=GOLD)]}]),

        tx(em(0.65), em(2.5), em(5.0), em(2.5),
           [{"align": "l", "runs": [R("Myers-Briggs built a category. Enneagram built one. Vedic astrology", 15, c=DIM)]},
            None,
            {"align": "l", "runs": [R("is 5,000 years older, mathematically richer, and still waiting for", 15, c=DIM)]},
            None,
            {"align": "l", "runs": [R("its social layer. Aurogram is that layer.", 15, b=True, c=WHITE)]}]),

        # Market number
        tx(em(0.65), em(5.0), em(4.5), em(0.5),
           [{"align": "l", "runs": [R("$14.2B astrology market · 4.9B social media users · zero overlap today.", 13, c=DIM, i=True)]}]),

        # Right: ask card
        sp(em(6.1), em(0.8), em(3.3), em(5.8), CARD),
        sp(em(6.1), em(0.8), em(0.07), em(5.8), GOLD),

        tx(em(6.35), em(1.0), em(2.85), em(0.6),
           [{"align": "l", "runs": [R("WE'RE LOOKING FOR", 12, b=True, c=GOLD)]}]),

        *_ask_item(em(6.35), em(1.7),  "Beta community builders"),
        *_ask_item(em(6.35), em(2.4),  "Astrology / wellness brands"),
        *_ask_item(em(6.35), em(3.1),  "Strategic distribution partners"),
        *_ask_item(em(6.35), em(3.8),  "Advisors in AI or social"),

        sp(em(6.1), em(5.3), em(3.3), em(1.1), WARM),
        tx(em(6.25), em(5.35), em(3.0), em(1.0),
           [{"align": "c", "runs": [R("aurogram.app", 18, b=True, c=WHITE)]},
            {"align": "c", "runs": [R("Let's build the cosmic social layer.", 12, c=GOLD)]}],
           anchor="m"),
    ])

def _ask_item(x, y, text):
    return [
        tx(x, y, em(2.85), em(0.55),
           [{"align": "l", "runs": [R("→  ", 14, b=True, c=GOLD), R(text, 14, c=WHITE)]}]),
    ]

# ─────────────────────────────────────────────────────────────────────────────
# BOILERPLATE XML
# ─────────────────────────────────────────────────────────────────────────────
NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships"

CT = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml"  ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide3.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide4.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml"  ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>'''

ROOT_RELS = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>'''

PRES = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" saveSubsetFonts="1">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>
    <p:sldId id="257" r:id="rId2"/>
    <p:sldId id="258" r:id="rId3"/>
    <p:sldId id="259" r:id="rId4"/>
    <p:sldId id="260" r:id="rId5"/>
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>'''

PRES_RELS = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide3.xml"/>
  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide4.xml"/>
</Relationships>'''

MASTER = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="080C14"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree></p:cSld>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
  <p:txStyles><p:titleStyle><a:lstStyle/></p:titleStyle><p:bodyStyle><a:lstStyle/></p:bodyStyle><p:otherStyle><a:lstStyle/></p:otherStyle></p:txStyles>
</p:sldMaster>'''

MASTER_RELS = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>'''

LAYOUT = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" type="blank" preserve="1">
  <p:cSld name="Blank"><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
  </p:spTree></p:cSld>
</p:sldLayout>'''

LAYOUT_RELS = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>'''

THEME = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Aurogram">
  <a:themeElements>
    <a:clrScheme name="Aurogram">
      <a:dk1><a:srgbClr val="080C14"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="0D1420"/></a:dk2><a:lt2><a:srgbClr val="E8EDF5"/></a:lt2>
      <a:accent1><a:srgbClr val="C9A96E"/></a:accent1><a:accent2><a:srgbClr val="5A3D34"/></a:accent2>
      <a:accent3><a:srgbClr val="4A7FA5"/></a:accent3><a:accent4><a:srgbClr val="4E9A6F"/></a:accent4>
      <a:accent5><a:srgbClr val="6B4E71"/></a:accent5><a:accent6><a:srgbClr val="4A5568"/></a:accent6>
      <a:hlink><a:srgbClr val="C9A96E"/></a:hlink><a:folHlink><a:srgbClr val="5A3D34"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Aurogram">
      <a:majorFont><a:latin typeface="Segoe UI"/></a:majorFont>
      <a:minorFont><a:latin typeface="Segoe UI"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>'''

SLIDE_RELS = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>'''

CORE = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Aurogram</dc:title><dc:creator>Aurogram</dc:creator>
</cp:coreProperties>'''

APP = b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>Aurogram</Application><Slides>4</Slides>
</Properties>'''

# ─────────────────────────────────────────────────────────────────────────────
OUT = '/Users/a0v0hxf/local/AG/tribes/Aurogram_Pitch_Deck.pptx'

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', CT)
    z.writestr('_rels/.rels', ROOT_RELS)
    z.writestr('ppt/presentation.xml', PRES)
    z.writestr('ppt/_rels/presentation.xml.rels', PRES_RELS)
    z.writestr('ppt/theme/theme1.xml', THEME)
    z.writestr('ppt/slideMasters/slideMaster1.xml', MASTER)
    z.writestr('ppt/slideMasters/_rels/slideMaster1.xml.rels', MASTER_RELS)
    z.writestr('ppt/slideLayouts/slideLayout1.xml', LAYOUT)
    z.writestr('ppt/slideLayouts/_rels/slideLayout1.xml.rels', LAYOUT_RELS)
    z.writestr('docProps/core.xml', CORE)
    z.writestr('docProps/app.xml', APP)
    for i, fn in enumerate([s1, s2, s3, s4], 1):
        z.writestr(f'ppt/slides/slide{i}.xml', fn())
        z.writestr(f'ppt/slides/_rels/slide{i}.xml.rels', SLIDE_RELS)

import os
size = os.path.getsize(OUT)
print(f"✅  {OUT}  ({size:,} bytes, 4 slides)")
