#!/usr/bin/env python3
"""Generate Aurogram pitch deck PPTX using stdlib only."""
import zipfile, io, textwrap
from xml.etree.ElementTree import Element, SubElement, tostring
from datetime import datetime

# EMU constants
W = 9144000   # 10 inches
H = 6858000   # 7.5 inches
INCH = 914400

# Colors (hex without #)
BG_DARK   = "080C14"
ACCENT    = "5A3D34"
GOLD      = "C9A96E"
WHITE     = "FFFFFF"
GRAY      = "8899AA"
BLUE_ACC  = "4A7FA5"
CARD_BG   = "0F1825"

def emu(inches): return int(inches * INCH)

def xml_str(el):
    return b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' + tostring(el, encoding='unicode').encode('utf-8')

# ── Content Types ──────────────────────────────────────────────────────────────
def content_types_xml(n_slides):
    root = Element('Types', xmlns="http://schemas.openxmlformats.org/package/2006/content-types")
    def D(ext, ct): SubElement(root,'Default',Extension=ext,ContentType=ct)
    def O(pn, ct):  SubElement(root,'Override',PartName=pn,ContentType=ct)
    D('rels','application/vnd.openxmlformats-package.relationships+xml')
    D('xml','application/xml')
    O('/ppt/presentation.xml','application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml')
    O('/ppt/slideMasters/slideMaster1.xml','application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml')
    O('/ppt/slideLayouts/slideLayout1.xml','application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml')
    O('/ppt/theme/theme1.xml','application/vnd.openxmlformats-officedocument.theme+xml')
    for i in range(1, n_slides+1):
        O(f'/ppt/slides/slide{i}.xml','application/vnd.openxmlformats-officedocument.presentationml.slide+xml')
    O('/docProps/core.xml','application/vnd.openxmlformats-package.core-properties+xml')
    O('/docProps/app.xml','application/vnd.openxmlformats-officedocument.extended-properties+xml')
    return xml_str(root)

# ── Relationships ──────────────────────────────────────────────────────────────
NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships"

def root_rels():
    root = Element('Relationships', xmlns=NS_REL)
    def R(id,t,tgt): SubElement(root,'Relationship',Id=id,Type=t,Target=tgt)
    base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    R('rId1',f'{base}/officeDocument','ppt/presentation.xml')
    R('rId2','http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties','docProps/core.xml')
    R('rId3',f'{base}/extended-properties','docProps/app.xml')
    return xml_str(root)

def pres_rels(n_slides):
    root = Element('Relationships', xmlns=NS_REL)
    base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    SubElement(root,'Relationship',Id='rId1',Type=f'{base}/slideMaster',Target='slideMasters/slideMaster1.xml')
    for i in range(1, n_slides+1):
        SubElement(root,'Relationship',Id=f'rId{i+1}',Type=f'{base}/slide',Target=f'slides/slide{i}.xml')
    return xml_str(root)

def slide_master_rels():
    root = Element('Relationships', xmlns=NS_REL)
    base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    SubElement(root,'Relationship',Id='rId1',Type=f'{base}/slideLayout',Target='../slideLayouts/slideLayout1.xml')
    SubElement(root,'Relationship',Id='rId2',Type=f'{base}/theme',Target='../theme/theme1.xml')
    return xml_str(root)

def slide_layout_rels():
    root = Element('Relationships', xmlns=NS_REL)
    base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    SubElement(root,'Relationship',Id='rId1',Type=f'{base}/slideMaster',Target='../slideMasters/slideMaster1.xml')
    return xml_str(root)

def slide_rels(slide_num):
    root = Element('Relationships', xmlns=NS_REL)
    base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    SubElement(root,'Relationship',Id='rId1',Type=f'{base}/slideLayout',Target='../slideLayouts/slideLayout1.xml')
    return xml_str(root)

# ── Theme ──────────────────────────────────────────────────────────────────────
def theme_xml():
    return b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Aurogram">
  <a:themeElements>
    <a:clrScheme name="Aurogram">
      <a:dk1><a:srgbClr val="080C14"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="0F1825"/></a:dk2>
      <a:lt2><a:srgbClr val="E8EDF5"/></a:lt2>
      <a:accent1><a:srgbClr val="5A3D34"/></a:accent1>
      <a:accent2><a:srgbClr val="C9A96E"/></a:accent2>
      <a:accent3><a:srgbClr val="4A7FA5"/></a:accent3>
      <a:accent4><a:srgbClr val="6B4E71"/></a:accent4>
      <a:accent5><a:srgbClr val="2E7D5E"/></a:accent5>
      <a:accent6><a:srgbClr val="8899AA"/></a:accent6>
      <a:hlink><a:srgbClr val="C9A96E"/></a:hlink>
      <a:folHlink><a:srgbClr val="5A3D34"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Aurogram">
      <a:majorFont><a:latin typeface="Segoe UI" panose="020B0604020202020204"/></a:majorFont>
      <a:minorFont><a:latin typeface="Segoe UI" panose="020B0604020202020204"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>'''

# ── Slide Master ───────────────────────────────────────────────────────────────
def slide_master_xml():
    return b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="080C14"/></a:solidFill></p:bgPr></p:bg>
    <p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
  <p:txStyles>
    <p:titleStyle><a:lstStyle><a:defPPr><a:defRPr lang="en-US" b="1"/></a:defPPr></a:lstStyle></p:titleStyle>
    <p:bodyStyle><a:lstStyle/></p:bodyStyle>
    <p:otherStyle><a:lstStyle/></p:otherStyle>
  </p:txStyles>
</p:sldMaster>'''

# ── Slide Layout ───────────────────────────────────────────────────────────────
def slide_layout_xml():
    return b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             type="blank" preserve="1">
  <p:cSld name="Blank"><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
  </p:spTree></p:cSld>
</p:sldLayout>'''

# ── Presentation ───────────────────────────────────────────────────────────────
def presentation_xml(n_slides):
    lines = [
        b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        b'<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"',
        b'  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"',
        b'  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"',
        b'  saveSubsetFonts="1">',
        b'  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>',
        b'  <p:sldIdLst>',
    ]
    for i in range(1, n_slides+1):
        lines.append(f'    <p:sldId id="{256+i}" r:id="rId{i+1}"/>'.encode())
    lines += [
        b'  </p:sldIdLst>',
        b'  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>',
        b'  <p:notesSz cx="6858000" cy="9144000"/>',
        b'</p:presentation>',
    ]
    return b'\n'.join(lines)

# ── Slide Builder ──────────────────────────────────────────────────────────────
ANS = "http://schemas.openxmlformats.org/drawingml/2006/main"
PNS = "http://schemas.openxmlformats.org/presentationml/2006/main"
RNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

def make_slide(shapes_xml_list):
    """shapes_xml_list: list of raw XML strings for each shape."""
    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"',
        '  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"',
        '  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
        '  <p:cSld>',
        '    <p:bg><p:bgPr><a:solidFill><a:srgbClr val="080C14"/></a:solidFill></p:bgPr></p:bg>',
        '    <p:spTree>',
        '      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>',
        '      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>',
        '        <a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>',
    ]
    parts.extend(shapes_xml_list)
    parts += ['    </p:spTree>', '  </p:cSld>', '</p:sld>']
    return '\n'.join(parts).encode('utf-8')

_shape_id = [2]
def next_id():
    _shape_id[0] += 1
    return _shape_id[0]

def rect(x, y, cx, cy, fill_hex, alpha=None, name="rect"):
    sid = next_id()
    a = f'<a:alpha val="{alpha}000"/>' if alpha else ''
    return f'''<p:sp>
  <p:nvSpPr><p:cNvPr id="{sid}" name="{name}"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
  <p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="{fill_hex}">{a}</a:srgbClr></a:solidFill>
    <a:ln><a:noFill/></a:ln>
  </p:spPr>
  <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
</p:sp>'''

def textbox(x, y, cx, cy, runs, align='l', wrap=True, anchor='t', name="txt"):
    """runs: list of (text, size_pt, bold, color_hex, italic)"""
    sid = next_id()
    wrap_attr = 'none' if not wrap else 'sq'
    algn_map = {'l':'l','c':'ctr','r':'r','j':'just'}
    algn = algn_map.get(align,'l')
    anchor_map = {'t':'t','m':'ctr','b':'b'}
    anc = anchor_map.get(anchor,'t')
    paras = []
    for run_group in runs:
        if run_group is None:
            paras.append('<a:p/>')
            continue
        if not isinstance(run_group, list):
            run_group = [run_group]
        rxml = ''
        for item in run_group:
            if isinstance(item, str):
                text,size,bold,color,italic = item,1800,False,WHITE,False
            else:
                text = item.get('t','')
                size = int(item.get('sz',18)*100)
                bold = item.get('b',False)
                color = item.get('c',WHITE)
                italic = item.get('i',False)
            b_tag = '<a:b val="1"/>' if bold else '<a:b val="0"/>'
            i_tag = '<a:i val="1"/>' if italic else ''
            text_esc = text.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
            rxml += f'''<a:r><a:rPr lang="en-US" sz="{size}" dirty="0" b="{1 if bold else 0}" i="{1 if italic else 0}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill><a:latin typeface="Segoe UI"/></a:rPr><a:t>{text_esc}</a:t></a:r>'''
        paras.append(f'<a:p><a:pPr algn="{algn}"/>{rxml}</a:p>')
    para_xml = '\n'.join(paras)
    return f'''<p:sp>
  <p:nvSpPr><p:cNvPr id="{sid}" name="{name}"/><p:cNvSpPr txBox="1"><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr/></p:nvSpPr>
  <p:spPr><a:xfrm><a:off x="{x}" y="{y}"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:noFill/><a:ln><a:noFill/></a:ln>
  </p:spPr>
  <p:txBody><a:bodyPr wrap="{wrap_attr}" anchor="{anc}"><a:spAutoFit/></a:bodyPr><a:lstStyle/>
  {para_xml}
  </p:txBody>
</p:sp>'''

def R(t, sz=18, b=False, c=WHITE, i=False):
    return {'t':t,'sz':sz,'b':b,'c':c,'i':i}

def bullet(x, y, cx, items, title=None, title_color=GOLD):
    shapes = []
    cy_offset = 0
    if title:
        shapes.append(textbox(x, y, cx, emu(0.5), [[R(title, 16, b=True, c=title_color)]], align='l'))
        cy_offset = emu(0.5)
    bullet_runs = []
    for item in items:
        if isinstance(item, str):
            bullet_runs.append([R(f"▸  {item}", 14, c=WHITE)])
        else:
            bullet_runs.append([R(f"▸  ", 14, c=GOLD, b=True), R(item[0], 14, c=WHITE), *([] if len(item)<2 else [R(f" — {item[1]}", 13, c=GRAY, i=True)])])
        bullet_runs.append(None)
    shapes.append(textbox(x, y+cy_offset, cx, emu(4), bullet_runs, align='l'))
    return '\n'.join(shapes)

def accent_bar(x, y, cx=emu(0.06), cy=emu(0.7), color=GOLD):
    return rect(x, y, cx, cy, color)

def slide_num_label(n, total=10):
    return textbox(emu(9.3), emu(7.1), emu(0.6), emu(0.3),
                   [[R(f"{n} / {total}", 10, c=GRAY)]], align='r', name="slidenum")

# ══════════════════════════════════════════════════════════════════════════════
# SLIDES
# ══════════════════════════════════════════════════════════════════════════════

def slide1_cover():
    _shape_id[0] = 2
    shapes = []
    # gradient-like bg strips
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))  # top bar
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))  # bottom bar
    # big decorative circle (top-right glow)
    shapes.append(rect(emu(6.5), emu(-1), emu(5), emu(5), "1A0F0D", name="glow"))
    # logo placeholder circle
    shapes.append(rect(emu(0.6), emu(1.1), emu(1.2), emu(1.2), ACCENT, name="logo_bg"))
    shapes.append(textbox(emu(0.7), emu(1.2), emu(1.0), emu(1.0),
                          [[R("✦", 36, c=GOLD)]], align='c'))
    # App name
    shapes.append(textbox(emu(2.0), emu(1.0), emu(7.5), emu(1.4),
                          [[R("AUROGRAM", 54, b=True, c=WHITE)]], align='l'))
    # Tagline
    shapes.append(accent_bar(emu(2.0), emu(2.55), emu(0.07), emu(0.5), GOLD))
    shapes.append(textbox(emu(2.2), emu(2.5), emu(7), emu(0.7),
                          [[R("Connect with Your Tribe Through AI, Astrology & Real-Time Community", 20, c=GOLD)]], align='l'))
    # Description
    shapes.append(textbox(emu(2.0), emu(3.4), emu(7), emu(1.0),
                          [[R("A cross-platform social platform uniting community spaces, Vedic astrology insights,", 15, c=GRAY)],
                           [R("AI-powered conversations, and real-time video — all in one app.", 15, c=GRAY)]], align='l'))
    # Platforms
    shapes.append(textbox(emu(2.0), emu(4.8), emu(6), emu(0.5),
                          [[R("iOS  •  Android  •  Web  •  macOS  •  Windows", 13, c=BLUE_ACC)]], align='l'))
    # Built with
    shapes.append(textbox(emu(2.0), emu(5.4), emu(6), emu(0.5),
                          [[R("Flutter  ·  Firebase  ·  Gemini AI  ·  Agora", 12, c=GRAY, i=True)]], align='l'))
    return make_slide(shapes)

def slide2_problem():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    # Title
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("The Problem", 36, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    shapes.append(textbox(emu(0.5), emu(1.2), emu(9), emu(0.5),
                          [[R("Social media is broken — fragmented, soulless, and algorithmically hostile.", 17, c=GOLD)]], align='l'))
    # 3 problem cards
    card_data = [
        ("🧩", "Fragmented Experiences", "Users juggle 5+ apps for chat, video, community,\nastrology, and wellness. No single cohesive home."),
        ("🤖", "AI Without Context", "Generic AI chatbots don't know your birth chart,\nyour tribe, or your spiritual path."),
        ("🌑", "No Cosmic Layer", "3.5B people follow astrology globally. Zero major\nsocial platform takes it seriously."),
    ]
    for i, (emoji, title, desc) in enumerate(card_data):
        cx_card = emu(2.8)
        x = emu(0.3) + i * emu(3.1)
        y = emu(2.0)
        shapes.append(rect(x, y, cx_card, emu(3.5), CARD_BG, name=f"card{i}"))
        shapes.append(rect(x, y, cx_card, emu(0.06), GOLD if i==0 else (BLUE_ACC if i==1 else ACCENT)))
        shapes.append(textbox(x+emu(0.15), y+emu(0.2), cx_card-emu(0.3), emu(0.6),
                              [[R(emoji, 28)]], align='l'))
        shapes.append(textbox(x+emu(0.15), y+emu(0.9), cx_card-emu(0.3), emu(0.6),
                              [[R(title, 15, b=True, c=GOLD)]], align='l'))
        shapes.append(textbox(x+emu(0.15), y+emu(1.4), cx_card-emu(0.3), emu(2.0),
                              [[R(desc, 13, c=GRAY)]], align='l'))
    shapes.append(slide_num_label(2))
    return make_slide(shapes)

def slide3_solution():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("Our Solution", 36, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    shapes.append(textbox(emu(0.5), emu(1.2), emu(9), emu(0.5),
                          [[R("Aurogram — one platform that combines your social life, cosmic identity, and AI guide.", 17, c=GOLD)]], align='l'))
    # Central hub diagram (text-based)
    shapes.append(rect(emu(3.8), emu(2.2), emu(2.4), emu(1.1), ACCENT, name="hub"))
    shapes.append(textbox(emu(3.8), emu(2.2), emu(2.4), emu(1.1),
                          [[R("AUROGRAM", 16, b=True, c=WHITE)], [R("Your Cosmic Hub", 11, c=GOLD)]], align='c', anchor='m'))
    # Spokes
    pillars = [
        (emu(0.3), emu(2.0), "🌟 Vedic\nAstrology", GOLD),
        (emu(0.3), emu(4.2), "👥 Community\nSpaces", BLUE_ACC),
        (emu(7.0), emu(2.0), "🤖 HolyCow\nAI Chat", "4E9A6F"),
        (emu(7.0), emu(4.2), "📹 Video &\nVoice Calls", "A0522D"),
    ]
    for px, py, label, color in pillars:
        shapes.append(rect(px, py, emu(2.2), emu(0.9), CARD_BG, name="pillar"))
        shapes.append(rect(px, py, emu(0.06), emu(0.9), color))
        shapes.append(textbox(px+emu(0.2), py, emu(2.0), emu(0.9),
                              [[R(label, 13, c=WHITE)]], align='l', anchor='m'))
    shapes.append(slide_num_label(3))
    return make_slide(shapes)

def slide4_features():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("Core Features", 36, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    # 6 feature cards in 2x3 grid
    features = [
        ("📡", "Live Feed", "Text, audio & video posts with reactions, comments, and shares"),
        ("🌐", "Spaces", "Community hubs with moderated chat, media, and events"),
        ("🔮", "Daily Astrology", "Personalized Vedic insights powered by your birth chart"),
        ("🤖", "HolyCow AI", "Gemini-powered AI that knows your chart and tribe"),
        ("📹", "Video Calls", "Real-time 1:1 and group calling via Agora SDK"),
        ("🎭", "Stories", "Ephemeral 24hr stories with rich media support"),
    ]
    cols, rows = 3, 2
    for i, (emoji, title, desc) in enumerate(features):
        col, row = i % cols, i // cols
        x = emu(0.3) + col * emu(3.1)
        y = emu(1.4) + row * emu(2.5)
        shapes.append(rect(x, y, emu(2.9), emu(2.3), CARD_BG))
        shapes.append(rect(x, y, emu(2.9), emu(0.06), GOLD if row==0 else BLUE_ACC))
        shapes.append(textbox(x+emu(0.15), y+emu(0.15), emu(2.6), emu(0.5),
                              [[R(f"{emoji}  {title}", 15, b=True, c=WHITE)]], align='l'))
        shapes.append(textbox(x+emu(0.15), y+emu(0.75), emu(2.6), emu(1.3),
                              [[R(desc, 12, c=GRAY)]], align='l'))
    shapes.append(slide_num_label(4))
    return make_slide(shapes)

def slide5_astrology():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("🔮  AI-Powered Vedic Astrology", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    shapes.append(textbox(emu(0.5), emu(1.2), emu(9), emu(0.5),
                          [[R("The first social platform to integrate real Vedic computation with AI interpretation.", 17, c=GOLD)]], align='l'))
    # Left: features list
    left_items = [
        "Jyotish birth chart (Rasi + Navamsa)",
        "22 cloud functions for daily cosmic insights",
        "Yoga detection: Raja, Viparita, Parivartana",
        "AI interprets planetary transits in plain language",
        "Compatibility matching between users",
        "Daily world energy forecast (Gemini LLM)",
        "Ayurveda dosha profiling integration",
    ]
    shapes.append(textbox(emu(0.5), emu(1.9), emu(4.8), emu(5),
                          [[R(f"✦  {item}", 13, c=WHITE)] for item in left_items] +
                          [None], align='l'))
    # Right: stat boxes
    stats = [
        ("3.5B+", "People follow astrology globally", GOLD),
        ("22", "Backend cloud functions for cosmic computation", BLUE_ACC),
        ("8/8", "Vedic signal types fully operational", "4E9A6F"),
    ]
    for i, (num, label, color) in enumerate(stats):
        y = emu(2.0) + i * emu(1.6)
        shapes.append(rect(emu(5.6), y, emu(3.8), emu(1.3), CARD_BG))
        shapes.append(rect(emu(5.6), y, emu(0.07), emu(1.3), color))
        shapes.append(textbox(emu(5.8), y+emu(0.1), emu(3.4), emu(0.6),
                              [[R(num, 30, b=True, c=color)]], align='l'))
        shapes.append(textbox(emu(5.8), y+emu(0.7), emu(3.4), emu(0.5),
                              [[R(label, 12, c=GRAY)]], align='l'))
    shapes.append(slide_num_label(5))
    return make_slide(shapes)

def slide6_spaces():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("👥  Community Spaces", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    shapes.append(textbox(emu(0.5), emu(1.2), emu(9), emu(0.5),
                          [[R("Tribe-based communities with real-time chat, media sharing, and moderation tools.", 17, c=GOLD)]], align='l'))
    left_feats = [
        ("🏠", "Public & Private Spaces", "Open communities or invite-only groups"),
        ("💬", "Real-Time Chat", "Instant messaging with media, reactions & threads"),
        ("🔔", "Smart Notifications", "FCM push + in-app notification center"),
        ("🎙️", "Anonymous Messages", "Confession-style anonymous post feature"),
    ]
    for i, (icon, title, desc) in enumerate(left_feats):
        y = emu(2.0) + i * emu(1.1)
        shapes.append(rect(emu(0.4), y, emu(4.2), emu(0.95), CARD_BG))
        shapes.append(textbox(emu(0.6), y+emu(0.05), emu(3.8), emu(0.4),
                              [[R(f"{icon}  {title}", 14, b=True, c=WHITE)]], align='l'))
        shapes.append(textbox(emu(0.6), y+emu(0.5), emu(3.8), emu(0.4),
                              [[R(desc, 12, c=GRAY)]], align='l'))
    # Right: why it works
    shapes.append(rect(emu(5.0), emu(1.9), emu(4.5), emu(4.8), CARD_BG))
    shapes.append(rect(emu(5.0), emu(1.9), emu(4.5), emu(0.06), GOLD))
    shapes.append(textbox(emu(5.2), emu(2.05), emu(4.1), emu(0.5),
                          [[R("Why Spaces Win", 16, b=True, c=GOLD)]], align='l'))
    reasons = [
        "Discord has servers, not cosmic identity",
        "Reddit has communities, not real-time video",
        "Instagram has video, not meaningful depth",
        "Aurogram has all three + your birth chart",
        "Shared astrology = instant tribe bonding",
        "Anonymous layer unlocks authentic sharing",
    ]
    for j, reason in enumerate(reasons):
        shapes.append(textbox(emu(5.2), emu(2.7) + j*emu(0.55), emu(4.1), emu(0.5),
                              [[R(f"▸  {reason}", 12, c=WHITE)]], align='l'))
    shapes.append(slide_num_label(6))
    return make_slide(shapes)

def slide7_tech():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("⚙️  Technical Architecture", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    layers = [
        ("Frontend", "Flutter 3.41+ · Dart 3.11+ · Provider State Mgmt · Offline Cache", GOLD),
        ("Backend", "Firebase Functions · Firestore · Auth · Storage · FCM · Crashlytics", BLUE_ACC),
        ("AI Layer", "Firebase AI (Gemini) · LangChain · OpenAI · Custom Vedic Engine", "4E9A6F"),
        ("Real-Time", "Agora SDK (video/voice) · Firestore streams · FCM push", "A0522D"),
        ("DevOps", "Firebase Hosting · App Check · Remote Config · CI/CD scripts", GRAY),
    ]
    for i, (layer, stack, color) in enumerate(layers):
        y = emu(1.5) + i * emu(1.0)
        shapes.append(rect(emu(0.4), y, emu(9.2), emu(0.85), CARD_BG))
        shapes.append(rect(emu(0.4), y, emu(0.07), emu(0.85), color))
        shapes.append(textbox(emu(0.65), y+emu(0.05), emu(1.5), emu(0.35),
                              [[R(layer, 13, b=True, c=color)]], align='l'))
        shapes.append(textbox(emu(2.3), y+emu(0.05), emu(7.1), emu(0.75),
                              [[R(stack, 13, c=WHITE)]], align='l', anchor='m'))
    # Bottom: cross-platform callout
    shapes.append(rect(emu(0.4), emu(6.6), emu(9.2), emu(0.5), ACCENT))
    shapes.append(textbox(emu(0.5), emu(6.6), emu(9.0), emu(0.5),
                          [[R("Single codebase → iOS · Android · Web · macOS · Windows", 14, b=True, c=WHITE)]], align='c', anchor='m'))
    shapes.append(slide_num_label(7))
    return make_slide(shapes)

def slide8_market():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("📈  Market Opportunity", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    # Big numbers
    stats = [
        ("$14.2B", "Global astrology market\nby 2031 (CAGR 6.2%)", GOLD),
        ("4.9B", "Social media users\nworldwide in 2025", BLUE_ACC),
        ("3.5B", "People who engage with\nastrology regularly", "4E9A6F"),
    ]
    for i, (num, label, color) in enumerate(stats):
        x = emu(0.4) + i * emu(3.1)
        shapes.append(rect(x, emu(1.5), emu(2.9), emu(1.8), CARD_BG))
        shapes.append(rect(x, emu(1.5), emu(2.9), emu(0.07), color))
        shapes.append(textbox(x+emu(0.15), emu(1.6), emu(2.6), emu(0.9),
                              [[R(num, 32, b=True, c=color)]], align='l'))
        shapes.append(textbox(x+emu(0.15), emu(2.5), emu(2.6), emu(0.7),
                              [[R(label, 12, c=GRAY)]], align='l'))
    # Competitive landscape
    shapes.append(textbox(emu(0.5), emu(3.5), emu(9), emu(0.4),
                          [[R("Competitive Landscape", 16, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(3.95), emu(9), emu(0.04), ACCENT))
    comp_data = [
        ("Co-Star / Pattern", "Astrology only, no community, no AI chat"),
        ("Discord / Reddit",   "Community only, no astrology, no cosmic identity"),
        ("Instagram / TikTok", "Video/social only, algorithmic, no depth"),
        ("✦  Aurogram",        "All three: social + cosmic identity + AI — first mover in this space"),
    ]
    for i, (name, desc) in enumerate(comp_data):
        y = emu(4.1) + i * emu(0.62)
        color = GOLD if i==3 else GRAY
        b_flag = i==3
        shapes.append(textbox(emu(0.5), y, emu(2.8), emu(0.55),
                              [[R(name, 13, b=b_flag, c=color)]], align='l'))
        shapes.append(textbox(emu(3.4), y, emu(6.0), emu(0.55),
                              [[R(desc, 13, c=WHITE if b_flag else GRAY)]], align='l'))
    shapes.append(slide_num_label(8))
    return make_slide(shapes)

def slide9_traction():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(8.5), emu(0.8),
                          [[R("🚀  Traction & Milestones", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(8.5), emu(0.05), GOLD))
    # Timeline
    milestones = [
        ("✅", "Shipped", "Full cross-platform app on iOS, Android, Web, macOS, Windows", GOLD),
        ("✅", "Live Backend", "22 Firebase Cloud Functions handling real-time astrology pipeline", GOLD),
        ("✅", "AI Integration", "Gemini-powered HolyCow AI with cosmic context awareness", GOLD),
        ("✅", "Vedic Engine", "8/8 signal types operational: aspects, yogas, parivartana, ingress", GOLD),
        ("🔄", "In Progress", "Ayurveda feature rollout + anonymous message enhancements", BLUE_ACC),
        ("🎯", "Next 90 Days", "Beta launch · App Store · Growth loop · Monetization v1", "4E9A6F"),
    ]
    for i, (icon, status, desc, color) in enumerate(milestones):
        y = emu(1.5) + i * emu(0.85)
        shapes.append(rect(emu(0.4), y, emu(9.2), emu(0.75), CARD_BG))
        shapes.append(rect(emu(0.4), y, emu(0.07), emu(0.75), color))
        shapes.append(textbox(emu(0.65), y+emu(0.05), emu(0.4), emu(0.35),
                              [[R(icon, 18)]], align='l'))
        shapes.append(textbox(emu(1.1), y+emu(0.05), emu(1.3), emu(0.35),
                              [[R(status, 13, b=True, c=color)]], align='l'))
        shapes.append(textbox(emu(2.5), y+emu(0.05), emu(6.9), emu(0.65),
                              [[R(desc, 13, c=WHITE)]], align='l', anchor='m'))
    shapes.append(slide_num_label(9))
    return make_slide(shapes)

def slide10_ask():
    _shape_id[0] = 2
    shapes = []
    shapes.append(rect(0, 0, W, H, "080C14"))
    shapes.append(rect(0, 0, W, emu(0.08), GOLD))
    shapes.append(rect(0, H-emu(0.08), W, emu(0.08), ACCENT))
    # Decorative
    shapes.append(rect(emu(6.0), emu(0.5), emu(4.5), emu(6.0), CARD_BG))
    shapes.append(rect(emu(6.0), emu(0.5), emu(0.06), emu(6.0), GOLD))
    shapes.append(textbox(emu(0.5), emu(0.3), emu(5.0), emu(0.8),
                          [[R("✦  Join the Journey", 34, b=True, c=WHITE)]], align='l'))
    shapes.append(accent_bar(emu(0.5), emu(1.05), emu(5.0), emu(0.05), GOLD))
    shapes.append(textbox(emu(0.5), emu(1.2), emu(5.0), emu(0.7),
                          [[R("We're looking for partners who believe in the\nfuture of cosmic-social technology.", 16, c=GOLD)]], align='l'))
    # Ask items
    ask_items = [
        ("💼", "Strategic Partnership", "Distribution, integrations, or co-marketing"),
        ("🌱", "Early Access Community", "Beta testers, brand ambassadors, tribe builders"),
        ("🤝", "Platform Collaboration", "Astrology, wellness, or spiritual-tech brands"),
        ("📣", "Feedback & Advisors", "Domain experts in astrology, AI, or social apps"),
    ]
    for i, (icon, title, desc) in enumerate(ask_items):
        y = emu(2.1) + i * emu(1.0)
        shapes.append(rect(emu(0.4), y, emu(5.0), emu(0.85), CARD_BG))
        shapes.append(textbox(emu(0.6), y+emu(0.05), emu(0.5), emu(0.5), [[R(icon, 20)]], align='l'))
        shapes.append(textbox(emu(1.2), y+emu(0.05), emu(4.0), emu(0.4),
                              [[R(title, 14, b=True, c=WHITE)]], align='l'))
        shapes.append(textbox(emu(1.2), y+emu(0.47), emu(4.0), emu(0.35),
                              [[R(desc, 12, c=GRAY)]], align='l'))
    # Right panel content
    shapes.append(textbox(emu(6.3), emu(0.9), emu(3.5), emu(0.5),
                          [[R("Why Now?", 20, b=True, c=GOLD)]], align='l'))
    why_now = [
        "Gemini 2.0 makes AI-astrology viable",
        "Gen-Z craves depth over dopamine",
        "Flutter enables one team, 5 platforms",
        "Vedic astrology goes mainstream globally",
        "Zero direct competitors in this niche",
    ]
    for i, w in enumerate(why_now):
        shapes.append(textbox(emu(6.3), emu(1.5) + i*emu(0.6), emu(3.5), emu(0.5),
                              [[R(f"✦  {w}", 13, c=WHITE)]], align='l'))
    # Contact
    shapes.append(rect(emu(6.0), emu(5.8), emu(3.6), emu(0.75), ACCENT))
    shapes.append(textbox(emu(6.1), emu(5.82), emu(3.4), emu(0.7),
                          [[R("aurogram.app", 16, b=True, c=WHITE)], [R("Let's build the cosmic social layer.", 11, c=GOLD)]], align='c', anchor='m'))
    shapes.append(slide_num_label(10))
    return make_slide(shapes)


# ══════════════════════════════════════════════════════════════════════════════
# ASSEMBLE & WRITE
# ══════════════════════════════════════════════════════════════════════════════

def build_pptx(output_path):
    slides = [
        slide1_cover(),
        slide2_problem(),
        slide3_solution(),
        slide4_features(),
        slide5_astrology(),
        slide6_spaces(),
        slide7_tech(),
        slide8_market(),
        slide9_traction(),
        slide10_ask(),
    ]
    n = len(slides)

    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', content_types_xml(n))
        z.writestr('_rels/.rels', root_rels())
        z.writestr('ppt/presentation.xml', presentation_xml(n))
        z.writestr('ppt/_rels/presentation.xml.rels', pres_rels(n))
        z.writestr('ppt/theme/theme1.xml', theme_xml())
        z.writestr('ppt/slideMasters/slideMaster1.xml', slide_master_xml())
        z.writestr('ppt/slideMasters/_rels/slideMaster1.xml.rels', slide_master_rels())
        z.writestr('ppt/slideLayouts/slideLayout1.xml', slide_layout_xml())
        z.writestr('ppt/slideLayouts/_rels/slideLayout1.xml.rels', slide_layout_rels())
        z.writestr('docProps/core.xml', b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Aurogram Pitch Deck</dc:title>
  <dc:creator>Aurogram</dc:creator>
</cp:coreProperties>''')
        z.writestr('docProps/app.xml', b'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>Aurogram Pitch Deck Generator</Application>
  <Slides>10</Slides>
</Properties>''')
        for i, slide_xml in enumerate(slides, 1):
            z.writestr(f'ppt/slides/slide{i}.xml', slide_xml)
            z.writestr(f'ppt/slides/_rels/slide{i}.xml.rels', slide_rels(i))

    print(f"✅ Created: {output_path}")

if __name__ == '__main__':
    build_pptx('/Users/a0v0hxf/local/AG/tribes/Aurogram_Pitch_Deck.pptx')
