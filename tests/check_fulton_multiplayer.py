"""Real mod Lua in isolated server/client VMs; transport and Java APIs mocked.

This checks protocol/trajectory behavior, not RakNet, OpenGL or a real PZ server.
"""
import math

from lua_harness import new_runtime


MOCKS = r"""
MilitaryDrop = {}
CLOCK, DT, LOADED, SPEED = 100000, .1, true, 1
GameTime = {getServerTimeMills = function() return CLOCK end}
getGameTime = function() return {getRealworldSecondsSinceLastUpdate = function() return DT end} end
getGameSpeed = function() return SPEED end
getCell = function() return {getGridSquare = function() return LOADED and {} or nil end} end
function player(id)
    return {id=id, dead=false, x=100, y=200, z=0,
        getOnlineID=function(self) return self.id end,
        getX=function(self) return self.x end, getY=function(self) return self.y end,
        getZ=function(self) return self.z end, isDead=function(self) return self.dead end}
end
PLAYERS = {player(1), player(2)}
getOnlinePlayers = function() return {
    size=function() return #PLAYERS end, get=function(_, i) return PLAYERS[i+1] end} end
getSpecificPlayer = function(i) return i == 0 and LOCAL or nil end
instanceItem = function(kind) return {kind=kind,
    setWorldAlpha=function(self, a) self.alpha=a end, setWorldScale=function() end} end
IsoPlayer = {getPlayerIndex=function() return 0 end}
DRAWS = {}
Render3DItem = function(item, square, x, y, z)
    DRAWS[#DRAWS+1] = {kind=item.kind, x=x, y=y, z=z}
end
renderIsoLine = function() end
FLYBYS = {}
getWorld = function() return {getFreeEmitter = function(_, x, y, z)
    return {playSoundImpl = function(_, name, loop, object)
        assert(loop == false, "unambiguous overload: playSoundImpl(name, false, nil)")
        FLYBYS[#FLYBYS+1] = {name=name, x=x, y=y, z=z}
    end}
end} end
"""


def plain(value):
    """Assert the wire contains only the primitives supported by PZ table transport."""
    if value is None or isinstance(value, (bool, str)):
        return value
    if isinstance(value, (int, float)):
        assert math.isfinite(value)
        return value
    assert hasattr(value, "items"), f"non-serializable payload: {type(value)}"
    return {plain(k): plain(v) for k, v in value.items()}


class Network:
    def __init__(self):
        self.commands, self.packets = [], []
        self.server = self.vm(server=True)
        self.clients = [self.vm(owner=1), self.vm(owner=2)]
        self.server.globals().sendServerCommand = self.broadcast
        self.server.execute('loadMod("server/MilitaryDrop/MilitaryDrop_FultonPrototypeServer.lua")')
        for index, client in enumerate(self.clients):
            client.globals().sendClientCommand = self.sender(index)
            client.execute('loadMod("client/MilitaryDrop/MilitaryDrop_FultonPrototype.lua")')

    @staticmethod
    def vm(server=False, owner=1):
        vm = new_runtime()
        vm.execute(MOCKS)
        vm.globals().SERVER = server
        vm.globals().OWNER = owner
        vm.execute('isServer=function() return SERVER end; isClient=function() return not SERVER end; '
                   'LOCAL=PLAYERS[OWNER]; loadMod("shared/MilitaryDrop/MilitaryDrop_FultonPrototypeFlight.lua")')
        return vm

    def sender(self, index):
        def send(player, module, command, args):
            self.commands.append((index, module, command, plain(args)))
        return send

    def broadcast(self, *args):
        if len(args) == 4:
            target, module, command, payload = args
            targets = [int(target.id) - 1]
        else:
            module, command, payload = args
            targets = range(len(self.clients))
        for index in targets:
            self.packets.append((index, module, command, plain(payload)))

    def command(self, packet=None):
        index, module, command, payload = packet or self.commands.pop(0)
        vm = self.server
        vm.globals().triggerEvent("OnClientCommand", module, command,
                                 vm.globals().PLAYERS[index + 1], vm.table_from(payload, recursive=True))

    def deliver(self, packets=None):
        if packets is None:
            packets, self.packets = self.packets, []
        for index, module, command, payload in packets:
            vm = self.clients[index]
            vm.globals().triggerEvent("OnServerCommand", module, command, vm.table_from(payload, recursive=True))

    def tick(self, seconds=.1, server=True):
        for vm in [self.server, *self.clients]:
            vm.globals().CLOCK += seconds * 1000
            vm.globals().DT = seconds
        if server:
            self.server.globals().triggerEvent("OnTick")
        for vm in self.clients:
            vm.globals().triggerEvent("OnTick")

    def start(self, index=0):
        assert self.clients[index].eval("MilitaryDrop.FultonPrototype.start(0)")
        self.command()
        self.deliver()

    def count(self, index):
        return self.clients[index].eval("MilitaryDrop.FultonPrototype.count()")

    def height(self, index):
        vm = self.clients[index]
        vm.execute('DRAWS={}; triggerEvent("OnPostRender")')
        return vm.globals().DRAWS[2].z


def check_shared_ascent_and_packet_delay():
    n = Network()
    n.clients[0].eval("MilitaryDrop.FultonPrototype.start(0)")
    assert n.count(0) == n.count(1) == 0, "no speculative private flight before server acceptance"
    n.command()
    assert n.packets[0][3]["flights"][1]["hold"] == 0, "server has no default waiting phase"
    n.tick(.9)  # delayed start snapshot; server also emits an updated snapshot
    n.deliver()
    n.tick(0, server=False)
    assert n.count(0) == n.count(1) == 1
    assert math.isclose(n.height(0), .95) and math.isclose(n.height(1), .95)
    n.clients[1].globals().SPEED = 0  # an observer's menu doesn't freeze the shared trajectory
    n.tick(2.1)
    n.deliver()
    assert math.isclose(n.height(0), 2.7) and math.isclose(n.height(1), 2.7)
    n.tick(.1)
    assert n.clients[0].eval("MilitaryDrop.FultonPrototype.status().phase") == "pickup"
    for vm in n.clients:
        vm.execute('DRAWS={}; triggerEvent("OnPostRender")')
        assert vm.globals().DRAWS[1].z > 0, "both clients immediately see the bag rising"
    n.tick(1.4)
    n.deliver()
    assert n.count(0) == n.count(1) == 0, "full cycle ends at 4.5s on server and clients"


def check_late_join_unloaded_square_and_reload():
    n = Network()
    n.start()
    n.tick(1.5)
    n.packets.clear()
    observer = n.clients[1]
    observer.execute('triggerEvent("OnDisconnect"); triggerEvent("OnGameStart")')
    n.command()
    n.deliver()
    n.tick(0, server=False)
    assert math.isclose(n.height(1), 1.45), "join restores current height, not launch height"
    observer.globals().LOADED = False
    n.tick(.1)
    observer.execute('DRAWS={}; triggerEvent("OnPostRender")')
    assert len(observer.globals().DRAWS) == 0 and n.count(1) == 1
    observer.globals().LOADED = True
    assert n.height(1) > 1.45
    observer.execute('loadMod("client/MilitaryDrop/MilitaryDrop_FultonPrototype.lua")')
    assert not n.commands, "local reload must not cancel a server flight"
    n.tick(.5)
    n.deliver()
    assert n.count(1) == 1 and observer.eval('listenerCount("OnServerCommand")') == 1


def check_unordered_commands_and_snapshots():
    n = Network()
    n.clients[0].eval("MilitaryDrop.FultonPrototype.start(0)")
    n.clients[0].eval("MilitaryDrop.FultonPrototype.stop()")
    start, stop = n.commands
    n.commands.clear()
    n.command(stop)
    n.command(start)
    n.deliver()
    assert n.count(0) == n.count(1) == 0, "a delayed Start cannot defeat a newer Stop"
    n.clients[0].eval("MilitaryDrop.FultonPrototype.start(0)")
    n.command()
    old, n.packets = n.packets, []
    n.clients[0].eval("MilitaryDrop.FultonPrototype.stop()")
    n.command()
    n.deliver()
    n.deliver(old)
    assert n.count(0) == n.count(1) == 0, "old full snapshots cannot resurrect stopped flights"


def check_two_flights_pause_ownership_and_disconnect():
    n = Network()
    n.start(0)
    n.start(1)
    assert n.count(0) == n.count(1) == 2
    n.clients[0].eval("MilitaryDrop.FultonPrototype.togglePause()")
    n.command()
    n.deliver()
    n.tick(1)
    n.deliver()
    assert n.clients[0].eval("MilitaryDrop.FultonPrototype.status().elapsed") == 0
    assert n.clients[1].eval("MilitaryDrop.FultonPrototype.status().elapsed") == 1
    # Player 2 attempts to pause player 1's flight: server must use actual sender.
    n.command((1, "MilitaryDropFultonPrototype", "Pause", {"request": 999, "id": 1, "paused": True}))
    n.tick(.5)
    n.deliver()
    assert n.clients[1].eval("MilitaryDrop.FultonPrototype.status().paused") is False
    # Even a high-sequence pause doesn't block an older Start targeting a new flight.
    n.command((0, "MilitaryDropFultonPrototype", "Pause", {"request": 1000, "id": 1, "paused": True}))
    n.command((0, "MilitaryDropFultonPrototype", "Start", {"request": 3}))
    n.deliver()
    assert n.clients[0].eval("MilitaryDrop.FultonPrototype.status().paused") is False
    n.server.execute('table.remove(PLAYERS, 1)')
    n.tick(.1)
    n.deliver()
    assert n.count(0) == n.count(1) == 1
    n.server.execute('PLAYERS[1].dead=true')
    n.tick(.1)
    n.deliver()
    assert n.count(0) == n.count(1) == 0
    assert n.server.eval('listenerCount("OnTick")') == 0


def check_server_bounds_and_completion():
    n = Network()
    n.command((0, "MilitaryDropFultonPrototype", "Start", {
        "request": 1, "owner": 2, "x": -1000, "z": 100, "elapsed": 90,
        "height": 999, "duration": .01, "hold": -9}))
    row = n.packets[0][3]["flights"][1]
    assert (row["owner"], row["x"], row["z"], row["elapsed"]) == (1, 101.5, 0, 0)
    assert (row["height"], row["duration"], row["hold"]) == (8, 1, 0)
    n.deliver()
    n.tick(3)  # authoritative monotonic clock catches up after a long server frame
    n.deliver()
    assert n.count(0) == n.count(1) == 0
    assert n.server.eval('listenerCount("OnTick")') == 0


def flybys(index, n):
    vm = n.clients[index]
    return [vm.globals().FLYBYS[i + 1].name for i in range(len(vm.globals().FLYBYS))]


def check_real_launch_is_anchored_shared_and_heard_once():
    n = Network()
    n.server.eval("MilitaryDrop.FultonPrototypeServer.startFlight(150.5, 250.5, 0)")
    row = n.packets[0][3]["flights"][1]
    assert row["real"] is True and (row["x"], row["y"], row["owner"]) == (150.5, 250.5, -1)
    n.deliver()
    assert n.count(0) == n.count(1) == 1, "every client sees the real flight"
    assert flybys(0, n) == flybys(1, n) == ["MilitaryDropFultonFlyby"], "each client plays the flyby once"
    emitter = n.clients[0].globals().FLYBYS[1]
    assert (emitter.x, emitter.y, emitter.z) == (150.5, 250.5, 20), "high emitter above the release point"
    n.server.execute('PLAYERS = {}')  # launcher and everyone disconnect: the flight still completes
    n.tick(1)
    n.deliver()
    assert n.count(0) == 1 and flybys(0, n) == ["MilitaryDropFultonFlyby"], "no second flyby on later snapshots"
    observer = n.clients[1]
    observer.execute('triggerEvent("OnDisconnect"); triggerEvent("OnGameStart")')
    n.server.execute('PLAYERS = {player(1), player(2)}')
    n.command()
    n.deliver()
    assert n.count(1) == 1 and flybys(1, n) == ["MilitaryDropFultonFlyby"], "late join: flight shown, no flyby"
    n.tick(3.5)
    n.deliver()
    assert n.count(0) == n.count(1) == 0, "real flight ends after 4.5 s"
    assert n.server.eval('listenerCount("OnTick")') == 0


def check_debug_menu_hidden_without_debug():
    n = Network()
    vm = n.clients[0]
    vm.execute('getDebug = function() return false end; ADDED = 0; '
               'CTX = {addOption = function() ADDED = ADDED + 1 end}; '
               'MilitaryDrop.FultonPrototype.onContext(0, CTX, {}, false)')
    assert vm.globals().ADDED == 0, "test menu only in debug mode"


def run_checks():
    for check in (check_shared_ascent_and_packet_delay, check_late_join_unloaded_square_and_reload,
                  check_unordered_commands_and_snapshots, check_two_flights_pause_ownership_and_disconnect,
                  check_server_bounds_and_completion, check_real_launch_is_anchored_shared_and_heard_once,
                  check_debug_menu_hidden_without_debug):
        try:
            check()
        except Exception as exc:
            yield check.__name__, str(exc) or type(exc).__name__
        else:
            yield check.__name__, None


if __name__ == "__main__":
    results = list(run_checks())
    for name, error in results:
        print(f"{'FAIL' if error else 'PASS'} {name}" + (f": {error}" if error else ""))
    raise SystemExit(any(error for _, error in results))
