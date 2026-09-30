import QtQuick
import Quickshell
import Quickshell.Io

// Everything the lamp knows, in one place, refreshed by one poll.
//
// The CLI (~/bin/govee-lamp) is the single source of truth: it owns the LAN
// protocol, the persisted mode and the systemd unit. This service only asks it
// for JSON and relays button presses back. That means the bar, the terminal
// and a reboot can never disagree about what the lamp is doing.
Item {
  id: root

  property var settings: ({})

  // The CLI ships inside this plugin, so resolve it relative to this file
  // rather than hardcoding a path. `omarchy plugin add` makes the whole repo
  // the plugin directory, so bin/govee-lamp is always right here, and the
  // shell's PATH does not include ~/bin anyway.
  readonly property string cli: {
    var u = Qt.resolvedUrl("bin/govee-lamp").toString()
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }

  property bool ready: false
  property bool reachable: false
  property bool lampOn: false
  property int brightness: 0
  property string lampColor: ""      // what the lamp is ACTUALLY showing
  property string mode: "theme"
  property string themeName: ""
  property string themeColor: ""
  property var palette: []
  property var modes: ["theme", "ambient", "circadian", "weather", "events", "music", "gauge", "off"]
  property string gaugeSource: "claude"
  property int workspace: 0
  property real ambientCycle: 15
  property real ambientCycleMin: 5
  property real ambientCycleMax: 60
  property var gaugeSources: []
  property int effectPid: 0
  // Per-device state. The frequent poll probes only the primary, so the full
  // fleet is only believed from a --all probe (run when the panel opens).
  property var devices: []

  readonly property int refreshSec: {
    var n = parseInt(String(settings && settings.refreshSec !== undefined ? settings.refreshSec : 5), 10)
    return isFinite(n) ? Math.max(2, Math.min(120, n)) : 5
  }

  // Set when a mode is chosen locally, so a poll that left before the CLI
  // applied it cannot bounce the selection back for a frame.
  property double modeSetAt: 0
  property double cycleSetAt: 0

  function apply(text) {
    var d
    try { d = JSON.parse(text) } catch (e) { return }
    if (!d) return
    reachable = !!d.reachable
    lampOn = !!d.on
    brightness = d.brightness || 0
    lampColor = d.lamp || ""
    if (Date.now() - modeSetAt > 2500) mode = d.mode || "theme"
    themeName = d.theme || ""
    themeColor = d.themeColor || ""
    palette = d.palette || []
    if (Array.isArray(d.modes) && d.modes.length) modes = d.modes
    gaugeSource = d.gaugeSource || "claude"
    workspace = d.workspace || 0
    // Do not fight the slider the user is currently dragging.
    if (Date.now() - cycleSetAt > 2500 && d.ambientCycle) ambientCycle = d.ambientCycle
    if (d.ambientCycleMin) ambientCycleMin = d.ambientCycleMin
    if (d.ambientCycleMax) ambientCycleMax = d.ambientCycleMax
    gaugeSources = d.gaugeSources || []
    effectPid = d.effect || 0
    if (Array.isArray(d.devices) && (d.probedAll || devices.length !== d.devices.length))
      devices = d.devices
    ready = true
  }

  Process {
    id: poll
    command: [root.cli, "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  // Actions are queued, not dropped. The first version returned early while a
  // previous action was still running, so a quick second click (very easy on a
  // grid of eight mode tiles) vanished with no feedback at all.
  property var pending: []

  Process {
    id: act
    onRunningChanged: if (!running) root.drain()
  }

  function drain() {
    if (act.running) return
    var q = root.pending
    if (!q || q.length === 0) return
    // Never mutate a QML var array in place. pending.shift() returned the item
    // but left the property holding the original array, so the queue never
    // emptied and every action re-ran forever -- which restarted the effect
    // unit in a loop and pinned the lamp on the first palette colour.
    var next = q[0]
    root.pending = q.slice(1)
    act.command = next
    act.running = true
  }

  function run(args) {
    // Cap the queue: holding a button down should not bank a hundred presses.
    var q = root.pending.slice(-3)
    q.push(args)
    root.pending = q
    drain()
    // Give the CLI a moment to act before believing the next poll.
    settle.restart()
  }

  Process {
    id: fleetPoll
    command: [root.cli, "json", "--all"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  function refreshFleet() { if (!fleetPoll.running) fleetPoll.running = true }

  function refresh() { if (!poll.running) poll.running = true }

  function setMode(m) { root.mode = m; root.modeSetAt = Date.now(); run([root.cli, "mode", m]) }
  function setBrightness(v) { root.brightness = v; run([root.cli, "brightness", String(v)]) }
  function setPower(on) { root.lampOn = on; run([root.cli, on ? "on" : "off"]) }
  function setAmbientCycle(v) {
    root.ambientCycle = v
    root.cycleSetAt = Date.now()
    run([root.cli, "ambient-cycle", String(v)])
  }
  function flash(kind) { run([root.cli, "flash", kind]) }

  Timer { id: settle; interval: 900; onTriggered: root.refresh() }

  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
