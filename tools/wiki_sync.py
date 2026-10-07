"""Convertit docs/guide en pages du wiki GitHub (liens et images absolus).

    git clone https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP.wiki.git <wiki>
    python tools/wiki_sync.py docs/guide <wiki> [--check]

Liens relatifs entre pages → URL du wiki (EN-/FR- + nom du fichier, README → Home),
images (Markdown et <img src="../images/…">) → raw.githubusercontent.com (branche main),
_Sidebar.md régénéré, pages EN-/FR- orphelines supprimées (git add -A). Vérifié le 2026-10-07 : reproduit à l'identique le wiki de la 0.3.2.
--check : liste les pages nouvelles ou modifiées sans rien écrire. Pousser le wiki ensuite.
"""
import re
import sys
from pathlib import Path

WIKI = "https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki/"
RAW = "https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/guide/"
LINK = re.compile(r"(!?)\[([^\]]*)\]\(([^)\s]+)\)")


def page_name(lang, rel):
    """Lien relatif d'une page de la langue lang → nom de page du wiki, ou None."""
    target = rel.split("#")[0]
    anchor = rel[len(target):]
    parts = target.split("/")
    if parts[0] == "..":
        if len(parts) == 2 and parts[1] == "README.md":
            return "Home" + anchor
        if len(parts) == 3 and parts[1] in ("en", "fr"):
            lang, target = parts[1], parts[2]
        else:
            return None
    elif target.startswith("en/") or target.startswith("fr/"):
        lang, target = target[:2], target[3:]
    if not target.endswith(".md"):
        return None
    stem = target[:-3]
    prefix = lang.upper() + "-"
    return (prefix + "Home" if stem == "README" else prefix + stem) + anchor


def convert(text, lang):
    def repl(match):
        bang, label, url = match.groups()
        if re.match(r"[a-z]+://", url) or url.startswith("#") or url.startswith("mailto:"):
            return match.group(0)
        if bang:
            clean = url[3:] if url.startswith("../") else url
            return f"![{label}]({RAW}{clean})"
        name = page_name(lang, url)
        if name is None:
            return match.group(0)
        return f"[{label}]({WIKI}{name})"
    text = LINK.sub(repl, text)
    return re.sub(r'src="\.\./([^"]+)"', lambda m: f'src="{RAW}{m.group(1)}"', text)


def build(guide):
    pages = {"Home.md": convert((guide / "README.md").read_text(encoding="utf-8"), "")}
    for lang in ("en", "fr"):
        for path in sorted((guide / lang).glob("*.md")):
            name = lang.upper() + "-" + ("Home" if path.stem == "README" else path.stem) + ".md"
            pages[name] = convert(path.read_text(encoding="utf-8"), lang)
    return pages


def sidebar(guide):
    lines = ["# Military Drop", "", f"[Home]({WIKI}Home)", ""]
    for lang, title in (("en", "English"), ("fr", "Français")):
        lines += [f"## {title}", ""]
        for path in [guide / lang / "README.md"] + sorted(p for p in (guide / lang).glob("*.md") if p.stem != "README"):
            heading = path.read_text(encoding="utf-8").splitlines()[0].lstrip("# ").strip()
            name = lang.upper() + "-" + ("Home" if path.stem == "README" else path.stem)
            lines.append(f"- [{heading}]({WIKI}{name})")
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n\n"


def main():
    guide, wiki = Path(sys.argv[1]), Path(sys.argv[2])
    pages = build(guide)
    pages["_Sidebar.md"] = sidebar(guide)
    check = "--check" in sys.argv
    for name, text in pages.items():
        path = wiki / name
        old = path.read_text(encoding="utf-8") if path.exists() else None
        status = "new" if old is None else ("same" if old == text else "changed")
        print(f"{status:8} {name}")
        if not check and status != "same":
            path.write_text(text, encoding="utf-8", newline="\n")
    # Pages de guide renommées ou retirées (EN-/FR- absentes de docs/guide) : supprimées.
    for path in sorted(wiki.glob("*.md")):
        if path.name[:3] in ("EN-", "FR-") and path.name not in pages:
            print(f"removed  {path.name}")
            if not check:
                path.unlink()


if __name__ == "__main__":
    main()
