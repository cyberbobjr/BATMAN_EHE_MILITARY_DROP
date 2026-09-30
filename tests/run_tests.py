"""Vérifications de Military Drop, sans lancer le jeu.

    python tests/run_tests.py [--require-luacheck]

1. luacheck (configuration .luacheckrc) ;
2. syntaxe Lua 5.1 de tous les fichiers du mod, appels à next() (absent de Kahlua) ;
3. traductions : JSON valides, mêmes clés et mêmes paramètres que EN, pas de % seul ;
4. descriptions Steam (README.steam*) : 8 000 octets UTF-8 au plus, BBCode équilibré,
   mêmes liens et images que l'anglais, description de workshop.txt identique à README.steam ;
5. tests Lua (tests/lua/test_*.lua) sous lupa, avec l'API du jeu simulée.

Dépendances : pip install lupa ; luacheck facultatif en local, exigé par la CI.
Les tests qui lisent les fichiers vanilla sont ignorés si le jeu est absent
(variable PZ_MEDIA, dossier media du jeu).
"""

import json
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lua_harness  # noqa: E402

REPO = lua_harness.REPO
MOD_LUA = lua_harness.MOD_LUA
TRANSLATE = MOD_LUA / "shared" / "Translate"
REFERENCE_LANGUAGE = "EN"

# next( précédé d'autre chose qu'un point, deux-points ou caractère de nom.
BARE_NEXT = re.compile(r"(?<![.:\w])next\s*\(")
TOKEN = re.compile(r"%\d|%%|<LINE>|<RGB:[^>]*>")
LONE_PERCENT = re.compile(r"%(?!\d)")
# Limite de Steam pour la description d'un objet du Workshop, en octets UTF-8 (envoi
# vérifié : 7 978 octets acceptés, 8 027 refusés avec EResult 8).
STEAM_DESCRIPTION_MAX_BYTES = 8000
STEAM_TAGS = ("h1", "h2", "h3", "b", "i", "u", "list", "table", "tr", "td", "url", "img")
# Liens et images : [url=…] et [img]…[/img].
STEAM_URL = re.compile(r"\[url=([^\]]+)\]|\[img\]([^\[]+)\[/img\]")


class Report:
    def __init__(self):
        self.failures = 0

    def section(self, title):
        print(f"\n== {title}")

    def ok(self, message):
        print(f"  ok    {message}")

    def skip(self, message):
        print(f"  --    {message}")

    def fail(self, message):
        self.failures += 1
        print(f"  ÉCHEC {message}")


def mod_lua_files():
    return sorted(MOD_LUA.rglob("*.lua"))


def strip_comments(line):
    # Suffisant pour repérer un appel : les chaînes contenant « -- » sont rares.
    return line.split("--", 1)[0]


def check_luacheck(report, required):
    report.section("luacheck")
    exe = shutil.which("luacheck")
    if not exe:
        if required:
            report.fail("luacheck introuvable")
        else:
            report.skip("luacheck introuvable (ignoré en local)")
        return
    result = subprocess.run([exe, "--formatter", "plain", "Contents", "tests"], cwd=REPO,
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode == 0:
        report.ok("aucun avertissement")
        return
    for line in (result.stdout + result.stderr).strip().splitlines():
        report.fail(line)


def check_kahlua(report):
    report.section("Syntaxe Lua 5.1 et fonctions absentes de Kahlua")
    files = mod_lua_files()
    errors = lua_harness.compile_errors(files)
    for error in errors:
        report.fail(error)
    if not errors:
        report.ok(f"{len(files)} fichiers compilés ({lua_harness.LUA_VERSION})")
    found = False
    for path in files:
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if BARE_NEXT.search(strip_comments(line)):
                found = True
                report.fail(f"{path.relative_to(REPO)}:{number} : next() n'existe pas dans Kahlua")
    if not found:
        report.ok("aucun appel à next()")


def load_json(path, report):
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        report.fail(f"{path.relative_to(REPO)} : BOM UTF-8")
    try:
        data = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        report.fail(f"{path.relative_to(REPO)} : JSON invalide ({error})")
        return None
    if not isinstance(data, dict) or not all(isinstance(v, str) for v in data.values()):
        report.fail(f"{path.relative_to(REPO)} : objet plat de chaînes attendu")
        return None
    return data


def check_lone_percent(report, path, data):
    for key, value in data.items():
        if LONE_PERCENT.search(value.replace("%%", "")):
            report.fail(f"{path.relative_to(REPO)} {key} : % seul (écrire %%)")


def check_translations(report):
    report.section("Traductions")
    reference_dir = TRANSLATE / REFERENCE_LANGUAGE
    reference = {}
    for path in sorted(reference_dir.glob("*.json")):
        data = load_json(path, report)
        if data is not None:
            reference[path.name] = data
            check_lone_percent(report, path, data)
    languages = sorted(p.name for p in TRANSLATE.iterdir() if p.is_dir() and p.name != REFERENCE_LANGUAGE)
    for language in languages:
        before = report.failures
        folder = TRANSLATE / language
        names = {p.name for p in folder.glob("*.json")}
        for missing in sorted(set(reference) - names):
            report.fail(f"{language} : {missing} manquant")
        for extra in sorted(names - set(reference)):
            report.fail(f"{language} : {extra} absent de {REFERENCE_LANGUAGE}")
        for name in sorted(names & set(reference)):
            path = folder / name
            data = load_json(path, report)
            if data is None:
                continue
            check_lone_percent(report, path, data)
            expected = reference[name]
            for key in sorted(set(expected) - set(data)):
                report.fail(f"{language}/{name} : clé manquante {key}")
            for key in sorted(set(data) - set(expected)):
                report.fail(f"{language}/{name} : clé en trop {key}")
            for key in sorted(set(data) & set(expected)):
                if Counter(TOKEN.findall(data[key])) != Counter(TOKEN.findall(expected[key])):
                    report.fail(f"{language}/{name} {key} : paramètres différents de {REFERENCE_LANGUAGE}")
        if report.failures == before:
            report.ok(f"{language} : {sum(len(d) for d in reference.values())} clés conformes")


def mod_ids():
    """id= des mod.info (common/ et variantes), comme SteamWorkshopItem.validateModDotInfo."""
    ids = []
    for info in sorted((REPO / "Contents" / "mods").glob("*/*/mod.info")):
        for line in info.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("id=") and line[3:].strip() not in ids:
                ids.append(line[3:].strip())
    return ids


def upload_suffix_length(workshop):
    """Octets ajoutés par le jeu à la description envoyée (SteamWorkshopItem.getSubmitDescription) :
    « \\n\\nWorkshop ID: <id> » puis « \\nMod ID: <id> » par mod."""
    workshop_id = next((line.split("=", 1)[1] for line in workshop if line.startswith("id=")), "")
    suffix = "\n\nWorkshop ID: " + workshop_id + "".join("\nMod ID: " + mod for mod in mod_ids())
    return len(suffix.encode("utf-8"))


def check_steam_descriptions(report):
    report.section("Descriptions Steam")
    reference_path = REPO / "README.steam"
    reference = reference_path.read_text(encoding="utf-8")
    reference_urls = Counter(STEAM_URL.findall(reference))
    workshop = (REPO / "workshop.txt").read_text(encoding="utf-8").splitlines()
    for path in sorted(REPO.glob("README.steam*")):
        text = path.read_text(encoding="utf-8")
        before = report.failures
        # Seule la description anglaise passe par l'envoi du jeu ; les autres langues
        # se saisissent sur la page Steam, sans suffixe.
        size = len(text.encode("utf-8"))
        limit = STEAM_DESCRIPTION_MAX_BYTES - (upload_suffix_length(workshop) if path == reference_path else 0)
        if size > limit:
            report.fail(f"{path.name} : {size} octets UTF-8 (Steam : {limit} au plus)")
        for tag in STEAM_TAGS:
            opened = len(re.findall(r"\[" + tag + r"(?:=[^\]]*)?\]", text))
            closed = text.count(f"[/{tag}]")
            if opened != closed:
                report.fail(f"{path.name} : [{tag}] ouvert {opened} fois, fermé {closed} fois")
        if Counter(STEAM_URL.findall(text)) != reference_urls:
            report.fail(f"{path.name} : liens ou images différents de README.steam")
        if report.failures == before:
            report.ok(f"{path.name} : {size} octets")
    description = [line[len("description="):] for line in workshop if line.startswith("description=")]
    if description != reference.splitlines():
        report.fail("workshop.txt : description différente de README.steam")
    else:
        report.ok("workshop.txt : description identique à README.steam")


def check_lua_tests(report):
    report.section(f"Tests Lua ({lua_harness.LUA_VERSION})")
    for path in sorted((Path(__file__).parent / "lua").glob("test_*.lua")):
        for name, error, skipped in lua_harness.run_test_file(path):
            label = f"{path.stem} : {name}"
            if skipped:
                report.skip(f"{label} ({error})")
            elif error:
                report.fail(f"{label}\n        {error}")
            else:
                report.ok(label)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    report = Report()
    check_luacheck(report, "--require-luacheck" in sys.argv)
    check_kahlua(report)
    check_translations(report)
    check_steam_descriptions(report)
    check_lua_tests(report)
    print()
    if report.failures:
        print(f"{report.failures} échec(s)")
        return 1
    print("Tout est bon.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
