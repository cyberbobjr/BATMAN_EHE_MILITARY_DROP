"""Vérifications de Military Drop, sans lancer le jeu.

    python tests/run_tests.py [--require-luacheck]

1. luacheck (configuration .luacheckrc) ;
2. syntaxe Lua 5.1 de tous les fichiers du mod, appels à next() (absent de Kahlua) ;
3. scripts du jeu : accolades équilibrées ; traductions : JSON valides, mêmes clés et mêmes paramètres que EN, pas de % seul ;
4. descriptions Steam (README.steam*) : 8 000 octets UTF-8 au plus, BBCode équilibré,
   mêmes liens et images que l'anglais, description de workshop.txt identique à README.steam ;
5. suivi de l'implémentation (docs/SUIVI.md) : identifiants uniques, états connus,
   preuve exigée pour un état « testé », commits cités présents dans git ;
6. tests Lua (tests/lua/test_*.lua) sous lupa, avec l'API du jeu simulée.

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


def check_references(report):
    """Clés et options citées en toutes lettres dans le Lua : présentes dans les
    traductions anglaises et dans sandbox-options.txt. Les clés composées à
    l'exécution (préfixe .. numéro) ne sont pas vérifiées ici."""
    report.section("Clés de traduction et options citées par le Lua")
    keys = set()
    for path in (TRANSLATE / REFERENCE_LANGUAGE).glob("*.json"):
        try:
            keys.update(json.loads(path.read_text(encoding="utf-8-sig")))
        except json.JSONDecodeError:
            return
    options = set(re.findall(r"^option MilitaryDrop\.(\w+)", (MOD_LUA.parent / "sandbox-options.txt")
                             .read_text(encoding="utf-8"), flags=re.M))
    text_key = re.compile(r"getText(?:OrNull)?\(\s*\"((?:IGUI|Tooltip|Sandbox)_[A-Za-z0-9_]+)\"\s*[,)]")
    option_use = re.compile(r"Config\.get\(\s*\"(\w+)\"\s*\)")
    missing = 0
    for path in mod_lua_files():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = strip_comments(line)
            for key in text_key.findall(code):
                if key not in keys:
                    missing += 1
                    report.fail(f"{path.relative_to(REPO)}:{number} : clé {key} absente de {REFERENCE_LANGUAGE}")
            for name in option_use.findall(code):
                if name not in options:
                    missing += 1
                    report.fail(f"{path.relative_to(REPO)}:{number} : option {name} absente de sandbox-options.txt")
    for name in sorted(options):
        for key in (f"Sandbox_MilitaryDrop_{name}", f"Sandbox_MilitaryDrop_{name}_tooltip"):
            if key not in keys:
                missing += 1
                report.fail(f"sandbox-options.txt : {name} sans traduction {key}")
    if not missing:
        report.ok(f"{len(options)} options et toutes les clés citées présentes")


def check_scripts(report):
    """Scripts du jeu (media/scripts) : accolades équilibrées, commentaires /* */ exclus."""
    report.section("Scripts d'objets et de véhicules")
    scripts = sorted((MOD_LUA.parent / "scripts").rglob("*.txt"))
    for path in scripts:
        text = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8"), flags=re.S)
        depth = 0
        for number, line in enumerate(text.splitlines(), 1):
            depth += line.count("{") - line.count("}")
            if depth < 0:
                report.fail(f"{path.relative_to(REPO)}:{number} : « }} » sans « {{ »")
                break
        if depth > 0:
            report.fail(f"{path.relative_to(REPO)} : {depth} accolade(s) non fermée(s)")
    report.ok(f"{len(scripts)} scripts relus")


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
        # Chaque langue est envoyée avec le suffixe « Workshop ID / Mod ID » en bas
        # (.claude/tools/pz_workshop_project.py, Project.descriptions).
        size = len(text.encode("utf-8"))
        limit = STEAM_DESCRIPTION_MAX_BYTES - upload_suffix_length(workshop)
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


TRACKING = REPO / "docs" / "SUIVI.md"
TRACKING_STATES = {
    "à décider", "décidé", "conçu", "codé", "testé hors jeu", "testé solo", "testé MP",
    "publié", "bloqué", "abandonné",
}
TRACKING_ID = re.compile(r"^[A-Z]+-\d{2}$")
TRACKING_COMMIT = re.compile(r"`([0-9a-f]{7,40})`")
TRACKING_NEEDS_PROOF = {"testé hors jeu", "testé solo", "testé MP", "publié"}


def tracking_rows(text):
    """Lignes des tableaux de suivi : (numéro de ligne, cellules) dont la 1re cellule est un ID.

    Une ligne d'élément qui n'a pas 6 cellules (un « | » dans un texte) est rendue
    avec ses cellules telles quelles : check_tracking la signale au lieu de l'ignorer.
    """
    for number, line in enumerate(text.splitlines(), 1):
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if re.match(r"^[A-Z]+-\d", cells[0]):
            yield number, cells


def commit_exists(sha):
    result = subprocess.run(
        ["git", "-C", str(REPO), "cat-file", "-e", f"{sha}^{{commit}}"],
        capture_output=True,
    )
    return result.returncode == 0


def shallow_clone():
    """Vrai pour un clone tronqué (CI par défaut) : les anciens commits y sont absents."""
    result = subprocess.run(
        ["git", "-C", str(REPO), "rev-parse", "--is-shallow-repository"],
        capture_output=True, text=True,
    )
    return result.returncode != 0 or result.stdout.strip() == "true"


def check_tracking(report):
    report.section("Suivi de l'implémentation (docs/SUIVI.md)")
    if not TRACKING.exists():
        report.fail("docs/SUIVI.md absent")
        return
    seen = {}
    rows = 0
    git = shutil.which("git") is not None and not shallow_clone()
    for number, cells in tracking_rows(TRACKING.read_text(encoding="utf-8")):
        rows += 1
        if len(cells) != 6:
            report.fail(f"SUIVI.md:{number} {cells[0]} : {len(cells)} cellules au lieu de 6 (« | » dans un texte ?)")
            continue
        ident, _, _, state, proofs, _ = cells
        where = f"SUIVI.md:{number} {ident}"
        if not TRACKING_ID.match(ident):
            report.fail(f"{where} : identifiant mal formé (FAMILLE-NN attendu)")
        if ident in seen:
            report.fail(f"{where} : identifiant déjà utilisé ligne {seen[ident]}")
        seen.setdefault(ident, number)
        if state not in TRACKING_STATES:
            report.fail(f"{where} : état inconnu « {state} »")
        if state in TRACKING_NEEDS_PROOF and proofs in ("", "—"):
            report.fail(f"{where} : état « {state} » sans preuve")
        if git:
            for sha in TRACKING_COMMIT.findall(proofs):
                if not commit_exists(sha):
                    report.fail(f"{where} : commit {sha} introuvable")
    if rows == 0:
        report.fail("aucune ligne de suivi trouvée")
    else:
        states = Counter(cells[3] for _, cells in tracking_rows(TRACKING.read_text(encoding="utf-8"))
                         if len(cells) == 6)
        summary = ", ".join(f"{count} {state}" for state, count in states.most_common())
        report.ok(f"{rows} éléments : {summary}")
    if not git:
        report.skip("git absent ou historique tronqué : commits cités non vérifiés")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    report = Report()
    check_luacheck(report, "--require-luacheck" in sys.argv)
    check_kahlua(report)
    check_scripts(report)
    check_references(report)
    check_translations(report)
    check_steam_descriptions(report)
    check_tracking(report)
    check_lua_tests(report)
    print()
    if report.failures:
        print(f"{report.failures} échec(s)")
        return 1
    print("Tout est bon.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
