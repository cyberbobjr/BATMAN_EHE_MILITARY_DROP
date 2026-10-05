"""Build Project Zomboid vehicle-mechanics diagrams for both helicopter wrecks."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (ROOT / "Contents/mods/batman_MilitaryDrop/common/media/ui/vehicles/mechanic overlay")
WIDTH, HEIGHT, SCALE = 263, 600, 4
HULL = (57, 64, 53, 255)
HULL_LIGHT = (76, 83, 68, 255)
HULL_DARK = (37, 43, 38, 255)
METAL = (111, 121, 112, 255)
EDGE = (211, 217, 205, 255)
SEAM = (133, 143, 132, 255)
GLASS = (23, 31, 31, 255)
GLASS_EDGE = (175, 190, 183, 255)
TRANSPARENT = (255, 255, 255, 0)


def point(xy):
    return tuple(round(value * SCALE) for value in xy)


def canvas():
    image = Image.new("RGBA", (WIDTH * SCALE, HEIGHT * SCALE), TRANSPARENT)
    return image, ImageDraw.Draw(image)


def polygon(draw, points, fill=HULL, outline=None, width=1):
    scaled = [point(p) for p in points]
    draw.polygon(scaled, fill=fill)
    if outline is not None:
        draw.line(scaled + [scaled[0]], fill=outline, width=width * SCALE, joint="curve")


def line(draw, points, width, fill=SEAM):
    draw.line([point(p) for p in points], fill=fill, width=width * SCALE, joint="curve")


def ellipse(draw, bounds, fill=HULL, outline=None, width=1):
    scaled = tuple(round(v * SCALE) for v in bounds)
    draw.ellipse(scaled, fill=fill, outline=outline, width=width * SCALE)


def save(image, filename):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).save(OUTPUT / filename)


def main_base():
    image, draw = canvas()
    # Muted olive metal gives the silhouette separation from the dark game scene.
    outline = [
        (131, 34), (151, 38), (169, 50), (182, 69), (188, 91), (185, 111),
        (178, 128), (192, 151), (196, 190), (197, 402), (190, 433),
        (177, 462), (160, 485), (148, 501), (139, 515), (132, 521),
        (125, 516), (115, 502), (103, 486), (86, 462), (73, 433),
        (66, 402), (67, 190), (71, 151), (85, 128), (78, 111), (75, 91),
        (81, 69), (94, 50), (112, 38),
    ]
    polygon(draw, outline, HULL, EDGE, 2)

    # Curved cockpit glazing with a center mullion and distinct cracked panes.
    canopy = [(94, 74), (103, 57), (117, 47), (132, 43), (147, 47),
              (161, 57), (171, 74), (177, 95), (170, 115), (153, 129),
              (132, 138), (111, 129), (94, 115), (87, 95)]
    polygon(draw, canopy, GLASS, GLASS_EDGE, 2)
    line(draw, [(132, 48), (132, 131)], 1, SEAM)
    line(draw, [(92, 92), (112, 98), (127, 89), (119, 78)], 1, GLASS_EDGE)
    line(draw, [(138, 87), (153, 76), (168, 92), (151, 105), (161, 116)], 1, GLASS_EDGE)
    line(draw, [(112, 118), (126, 108), (132, 112)], 1, GLASS_EDGE)

    # Side armor and access doors are outlined as separate repaired panels.
    polygon(draw, [(77, 157), (91, 143), (99, 152), (96, 204), (84, 214)], HULL_LIGHT, SEAM, 1)
    polygon(draw, [(187, 157), (173, 143), (165, 152), (168, 204), (180, 214)], HULL_LIGHT, SEAM, 1)
    line(draw, [(78, 221), (88, 211), (91, 286), (82, 298)], 1, SEAM)
    line(draw, [(185, 221), (175, 211), (172, 286), (181, 298)], 1, SEAM)
    line(draw, [(91, 150), (91, 197), (83, 205)], 1, EDGE)
    line(draw, [(172, 150), (172, 197), (180, 205)], 1, EDGE)
    line(draw, [(86, 304), (98, 315), (99, 352), (91, 368)], 2, EDGE)
    line(draw, [(177, 304), (165, 315), (164, 352), (172, 368)], 2, EDGE)
    line(draw, [(99, 363), (113, 370), (151, 370), (165, 363)], 2, SEAM)
    line(draw, [(101, 378), (113, 383), (151, 383), (163, 378)], 1, HULL_DARK)

    # Internal ribs and panel seams make the open, damaged cabin legible.
    for y in (175, 191, 275, 291, 401, 416, 451):
        line(draw, [(91, y), (105, y + 3), (159, y + 3), (173, y)], 1, SEAM)
    for x, y in ((89, 231), (174, 231), (91, 328), (171, 328),
                 (103, 395), (160, 395), (111, 461), (153, 461)):
        ellipse(draw, (x - 1.5, y - 1.5, x + 1.5, y + 1.5), EDGE)
    line(draw, [(102, 478), (112, 490), (122, 500)], 1, EDGE)
    line(draw, [(162, 478), (152, 490), (142, 500)], 1, EDGE)

    # Landing skids have a dark rail and a fine metal highlight.
    for points in (
        [(48, 151), (31, 178), (26, 205), (27, 420), (34, 454), (49, 482)],
        [(215, 151), (232, 178), (237, 205), (236, 420), (229, 454), (214, 482)],
    ):
        line(draw, points, 7, HULL_DARK)
        line(draw, points, 2, METAL)
    for y in (178, 435):
        for side in (-1, 1):
            line(draw, [(132, y), (132 + side * 66, y), (132 + side * 99, y + 20)], 5, HULL_DARK)
            line(draw, [(132, y), (132 + side * 66, y), (132 + side * 99, y + 20)], 1, METAL)

    # Crushed rotor blades retain a metallic edge around the hub.
    for blade in (
        [(131, 310), (89, 270)], [(131, 310), (174, 351)],
        [(131, 310), (174, 269)], [(131, 310), (89, 351)],
    ):
        line(draw, blade, 9, HULL_DARK)
        line(draw, blade, 5, METAL)
        line(draw, blade, 1, EDGE)
    ellipse(draw, (116, 295, 148, 327), HULL_DARK, EDGE, 2)
    ellipse(draw, (122, 301, 142, 321), HULL_LIGHT, SEAM, 1)
    ellipse(draw, (128, 307, 136, 315), METAL, EDGE, 1)
    return image


def main_parts():
    parts = {}
    parts["avionics"] = canvas()
    d = parts["avionics"][1]
    polygon(d, [(96, 78), (111, 63), (132, 57), (153, 63), (168, 78),
                (163, 106), (148, 121), (132, 128), (114, 121), (99, 106)], EDGE)
    line(d, [(132, 64), (132, 119)], 1, TRANSPARENT)
    line(d, [(101, 91), (119, 97), (129, 89)], 1, TRANSPARENT)
    line(d, [(135, 89), (151, 76), (163, 90), (147, 104)], 1, TRANSPARENT)

    parts["radiorack"] = canvas()
    d = parts["radiorack"][1]
    polygon(d, [(103, 211), (158, 211), (165, 220), (163, 255),
                (153, 265), (108, 262), (102, 250)], EDGE)
    for y in (223, 235, 247, 257):
        line(d, [(110, y), (155, y)], 1, TRANSPARENT)

    parts["enginebay"] = canvas()
    d = parts["enginebay"][1]
    polygon(d, [(94, 371), (108, 363), (155, 363), (169, 371),
                (176, 390), (172, 416), (157, 430), (105, 427),
                (91, 414), (87, 391)], EDGE)
    for x in (105, 112, 119, 145, 152, 159):
        line(d, [(x, 379), (x - 3, 410)], 1, TRANSPARENT)
    line(d, [(101, 418), (159, 420)], 1, TRANSPARENT)

    parts["rotorhub"] = canvas()
    d = parts["rotorhub"][1]
    ellipse(d, (112, 289, 150, 327), EDGE)
    ellipse(d, (120, 297, 142, 319), TRANSPARENT, TRANSPARENT, 2)
    line(d, [(131, 291), (131, 326)], 1, TRANSPARENT)
    line(d, [(114, 308), (149, 308)], 1, TRANSPARENT)

    parts["skinpanels"] = canvas()
    # The rear shell is split by transparent seams into readable repair panels.
    d = parts["skinpanels"][1]
    polygon(d, [(102, 445), (116, 439), (148, 439), (162, 445),
                (168, 460), (157, 481), (143, 490), (132, 486),
                (121, 490), (107, 481), (96, 460)], EDGE)
    line(d, [(132, 442), (132, 484)], 1, TRANSPARENT)
    line(d, [(104, 459), (124, 462), (132, 460), (140, 462), (160, 459)], 1, TRANSPARENT)
    return {name: pair[0] for name, pair in parts.items()}


def tail_base():
    image, draw = canvas()
    # Smooth tapered tail boom, fin and stabilizers in the same muted metal palette.
    boom = [(111, 80), (151, 80), (165, 96), (169, 119), (163, 151),
            (154, 190), (150, 252), (147, 333), (143, 415), (139, 481),
            (137, 511), (132, 526), (127, 511), (124, 481), (120, 415),
            (116, 333), (113, 252), (109, 190), (100, 151), (93, 119),
            (97, 96)]
    polygon(draw, boom, HULL, EDGE, 2)
    left_fin = [(116, 231), (59, 245), (43, 260), (48, 271),
                (63, 273), (112, 263)]
    right_fin = [(147, 231), (204, 245), (220, 260), (215, 271),
                 (200, 273), (151, 263)]
    polygon(draw, left_fin, HULL_LIGHT, EDGE, 2)
    polygon(draw, right_fin, HULL_LIGHT, EDGE, 2)

    # Recessed fin panels, boom seams and fasteners show the part boundaries.
    line(draw, [(113, 238), (63, 253), (51, 263), (64, 266), (111, 257)], 1, SEAM)
    line(draw, [(150, 238), (200, 253), (212, 263), (199, 266), (152, 257)], 1, SEAM)
    line(draw, [(120, 164), (124, 239), (126, 320), (130, 408), (132, 476)], 1, SEAM)
    line(draw, [(145, 164), (140, 239), (138, 320), (134, 408), (132, 476)], 1, SEAM)
    line(draw, [(112, 181), (151, 181)], 1, HULL_DARK)
    line(draw, [(115, 197), (149, 197)], 1, EDGE)
    line(draw, [(116, 350), (147, 350)], 1, SEAM)
    line(draw, [(118, 418), (143, 418)], 1, HULL_DARK)
    for x, y in ((117, 211), (146, 211), (119, 294), (144, 294),
                 (122, 380), (141, 380), (125, 450), (138, 450)):
        ellipse(draw, (x - 1, y - 1, x + 1, y + 1), EDGE)

    # Crossed, damaged tail-rotor blades, outlined so they read at panel scale.
    line(draw, [(101, 118), (161, 118)], 8, HULL_DARK)
    line(draw, [(131, 88), (131, 148)], 8, HULL_DARK)
    line(draw, [(101, 118), (161, 118)], 4, METAL)
    line(draw, [(131, 88), (131, 148)], 4, METAL)
    line(draw, [(101, 118), (161, 118)], 1, EDGE)
    line(draw, [(131, 88), (131, 148)], 1, EDGE)
    ellipse(draw, (120, 107, 142, 129), HULL_DARK, EDGE, 2)
    ellipse(draw, (126, 113, 136, 123), METAL, EDGE, 1)

    # Torn attachment end with exposed structural ribs.
    line(draw, [(119, 502), (126, 514), (131, 507), (137, 518), (143, 502)], 3, HULL_DARK)
    line(draw, [(119, 502), (126, 514), (131, 507), (137, 518), (143, 502)], 1, EDGE)
    line(draw, [(126, 484), (130, 494), (136, 482)], 1, SEAM)
    return image


def tail_parts():
    image, draw = canvas()
    # A single recoverable skin part, with seams to separate boom and fin panels.
    polygon(draw, [(112, 153), (151, 153), (160, 181), (154, 219),
                   (151, 258), (148, 335), (144, 413), (140, 467),
                   (137, 498), (132, 504), (126, 498), (123, 467),
                   (119, 413), (115, 335), (112, 258), (109, 219),
                   (103, 181)], EDGE)
    polygon(draw, [(116, 236), (62, 249), (55, 260), (60, 266),
                   (111, 257)], EDGE)
    polygon(draw, [(147, 236), (201, 249), (207, 260), (202, 266),
                   (152, 257)], EDGE)
    line(draw, [(132, 164), (132, 493)], 1, TRANSPARENT)
    line(draw, [(110, 184), (132, 189), (154, 184)], 1, TRANSPARENT)
    line(draw, [(117, 336), (132, 340), (147, 336)], 1, TRANSPARENT)
    line(draw, [(120, 414), (132, 417), (144, 414)], 1, TRANSPARENT)
    line(draw, [(65, 252), (108, 248)], 1, TRANSPARENT)
    line(draw, [(155, 248), (198, 252)], 1, TRANSPARENT)
    return image


def main():
    save(main_base(), "militarydrop_heli_wreck_base.png")
    for name, image in main_parts().items():
        save(image, f"militarydrop_heli_wreck_{name}.png")
    save(tail_base(), "militarydrop_heli_tail_base.png")
    save(tail_parts(), "militarydrop_heli_tail_skinpanels.png")


if __name__ == "__main__":
    main()
