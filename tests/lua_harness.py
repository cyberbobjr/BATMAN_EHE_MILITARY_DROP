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
MOD_COMMON = REPO / "Contents" / "mods" / "batman_MilitaryDrop" / "common"
PZ_MEDIA = Path(os.environ.get(
    "PZ_MEDIA", r"D:\SteamLibrary\steamapps\common\ProjectZomboid\media"))
VANILLA_LUA = PZ_MEDIA / "lua"
BWT_LUA = Path(os.environ.get("BWT_LUA", r"D:\SteamLibrary\steamapps\workshop\content\108600\3779480293\mods\BetterWalkieTalkies\42.20\media\lua"))

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

-- Charger réellement les seuls modules communs de radio ; les autres require
-- gardent les simulations propres à chaque fichier de test.
local radioModules = {}
require = function(name)
    if not name:find("BatmanRadio/", 1, true) then return end
    if not radioModules[name] then
        local scope = name == "BatmanRadio/BatmanRadio_Compat" and "shared/" or "client/"
        radioModules[name] = loadMod(scope .. name .. ".lua")
    end
    return radioModules[name]
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

-- Émetteur de getWorld():getFreeEmitter(x, y, z), fidèle aux surcharges Java de
-- FMODSoundEmitter (42.21, fmod/fmod/FMODSoundEmitter.java:380-490) telles que
-- Kahlua les résout. À utiliser pour tout son joué par le mod : une simulation
-- permissive avait laissé passer playSoundImpl(nom, nil), qui plante en jeu.
-- emitter.played : { name, x, y, z, looped, relayed } par son lancé ;
-- relayed = playSound*, renvoyé aux autres joueurs par un client MP.
function newSoundEmitter(x, y, z)
    local emitter = { x = x, y = y, z = z, played = {}, playing = {}, stopped = {}, nextId = 0 }
    local function start(self, name, looped, relayed)
        assert(type(name) == "string", "FMODSoundEmitter : nom de son attendu")
        self.nextId = self.nextId + 1
        self.played[#self.played + 1] = { name = name, x = self.x, y = self.y, z = self.z,
            looped = looped, relayed = relayed }
        self.playing[self.nextId] = name
        return self.nextId
    end
    local function square(sq, method)
        -- Un nil en second argument sélectionne la surcharge IsoGridSquare.
        if sq == nil then
            error(method .. "(String, IsoGridSquare) : square nil -> NullPointerException en jeu"
                .. " (Kahlua choisit cette surcharge pour nil ; utiliser playSoundImpl(nom, false, nil))", 3)
        end
        if type(sq) == "table" and sq.getX then
            return sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ()
        end
    end
    function emitter.setPos(self, px, py, pz) self.x, self.y, self.z = px, py, pz end
    function emitter.isPlaying(self, id) return self.playing[id] ~= nil end
    function emitter.stopSoundLocal(self, id) self.playing[id] = nil; self.stopped[#self.stopped + 1] = id end
    emitter.volumes = {}
    function emitter.setVolume(self, id, volume) self.volumes[id] = volume end
    function emitter.playSoundImpl(self, name, ...)
        local n, a = select("#", ...), ...
        if n == 0 then error("playSoundImpl(String) n'existe pas (No implementation found en jeu)", 2) end
        if n >= 2 and type(a) == "boolean" then
            return start(self, name, false, false) -- (String, boolean, IsoObject)
        end
        local sx, sy, sz = square(a, "playSoundImpl")
        if sx then self.x, self.y, self.z = sx, sy, sz end -- sinon (String, IsoObject)
        return start(self, name, false, false)
    end
    function emitter.playSoundLoopedImpl(self, name) return start(self, name, true, false) end
    function emitter.playSoundLooped(self, name) return start(self, name, true, true) end
    function emitter.playSound(self, name, ...)
        local n, a, b, c = select("#", ...), ...
        if n >= 3 then self.x, self.y, self.z = a, b, c
        elseif n >= 1 and type(a) ~= "boolean" then
            local sx, sy, sz = square(a, "playSound")
            if sx then self.x, self.y, self.z = sx, sy, sz end
        end
        return start(self, name, false, true)
    end
    return emitter
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
    # Ressource du dossier common du mod (textures des documents…).
    globals_.commonFileExists = lambda rel: (MOD_COMMON / rel).is_file()
    globals_.hasVanilla = VANILLA_LUA.is_dir()
    globals_.hasBWT = (BWT_LUA / "client/BetterWalkieTalkies/RadioPTT.lua").is_file()
    globals_.readBWTFile = lambda rel: _read(BWT_LUA, rel)
    globals_.readArtemisFile = lambda rel: _read(REPO.parent / "OperationArtemis/Contents/mods/batman_OperationArtemis/42.21/media/lua", rel)
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
