"""Environnement Lua pour les tests du mod (lupa).

Chaque cas de test tourne dans un runtime neuf, en Lua 5.1 si lupa le fournit
(Kahlua suit Lua 5.1). Le prélude retire `next`, absent de Kahlua : un appel
oublié échoue ici comme en jeu. L'API du jeu n'existe pas : chaque fichier de
test simule ce qu'il utilise, puis charge les fichiers du mod avec loadMod().
"""

import os
from pathlib import Path

try:
    from lupa import lua51 as lupa_module
    LUA_VERSION = "Lua 5.1"
except ImportError:  # lupa sans Lua 5.1 : on garde sa version par défaut
    import lupa as lupa_module
    LUA_VERSION = "Lua par défaut de lupa"

# lupa.lua51 lève sa propre LuaError, distincte de lupa.LuaError : l'importer
# depuis lupa ne rattrape pas l'échec d'un test, qui arrêtait tout le lanceur.
LuaError = lupa_module.LuaError

REPO = Path(__file__).resolve().parent.parent
MOD_LUA = REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "42.21" / "media" / "lua"
PZ_MEDIA = Path(os.environ.get(
    "PZ_MEDIA", r"D:\SteamLibrary\steamapps\common\ProjectZomboid\media"))
VANILLA_LUA = PZ_MEDIA / "lua"

PRELUDE = r"""
-- Kahlua n'a pas next() (pairs fonctionne sans elle).
next = nil
require = function() end
-- Les journaux du mod ([MilitaryDrop] …) ne polluent pas le rapport.
print = function() end

local compile = loadstring or load

local function run(source, name)
    local chunk, err = compile(source, "@" .. name)
    if not chunk then
        error(err, 3)
    end
    return chunk()
end

function loadMod(rel)
    return run(readModFile(rel), rel)
end

--- Fichier vanilla (lua/...) ; nil si le jeu n'est pas installé.
function loadVanilla(rel)
    local source = readVanillaFile(rel)
    if not source then
        return false
    end
    run(source, "vanilla/" .. rel)
    return true
end

function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s : attendu %s, obtenu %s", message or "assertEq",
            tostring(expected), tostring(actual)), 2)
    end
end

function assertTrue(value, message)
    if not value then
        error(message or "assertTrue", 2)
    end
end

-- Events : Add sans dédoublonnage et Remove, comme LuaEventManager.
Events = setmetatable({}, { __index = function(events, name)
    local event = { handlers = {} }
    function event.Add(f)
        table.insert(event.handlers, f)
    end
    function event.Remove(f)
        for i = #event.handlers, 1, -1 do
            if event.handlers[i] == f then
                table.remove(event.handlers, i)
                return
            end
        end
    end
    rawset(events, name, event)
    return event
end })

--- Déclenche un événement sur une copie de la liste (Remove permis pendant l'appel).
function triggerEvent(name, ...)
    local handlers = {}
    for i, f in ipairs(Events[name].handlers) do
        handlers[i] = f
    end
    for _, f in ipairs(handlers) do
        f(...)
    end
end

function listenerCount(name)
    return #Events[name].handlers
end
"""


def _read(base, rel):
    path = base / rel
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8", errors="replace")


def new_runtime():
    lua = lupa_module.LuaRuntime(unpack_returned_tuples=True)
    globals_ = lua.globals()

    def read_mod_file(rel):
        source = _read(MOD_LUA, rel)
        if source is None:
            raise FileNotFoundError(f"fichier du mod introuvable : {rel}")
        return source

    globals_.readModFile = read_mod_file
    globals_.readVanillaFile = lambda rel: _read(VANILLA_LUA, rel)
    globals_.hasVanilla = VANILLA_LUA.is_dir()
    lua.execute(PRELUDE)
    return lua


def compile_errors(paths):
    """Erreurs de syntaxe Lua 5.1 (goto, //, opérateurs binaires… refusés)."""
    lua = lupa_module.LuaRuntime()
    compile_ = lua.eval("loadstring or load")
    errors = []
    for path in paths:
        source = path.read_text(encoding="utf-8", errors="replace")
        result = compile_(source, "@" + path.name)
        if isinstance(result, tuple) and result[0] is None:
            errors.append(f"{path.relative_to(REPO)} : {result[1]}")
    return errors


def run_test_file(path):
    """Exécute chaque cas d'un fichier ; renvoie [(nom, erreur ou None, ignoré)]."""
    source = path.read_text(encoding="utf-8")
    listing = new_runtime()
    cases = listing.execute(source)
    skip = cases["skip"]
    names = sorted(str(k) for k in cases.keys() if k not in ("setup", "skip"))
    results = []
    for name in names:
        if skip:
            results.append((name, str(skip), True))
            continue
        lua = new_runtime()
        try:
            test_cases = lua.execute(source)
            if test_cases["setup"]:
                test_cases["setup"]()
            test_cases[name]()
            results.append((name, None, False))
        except LuaError as error:
            results.append((name, str(error), False))
    return results
