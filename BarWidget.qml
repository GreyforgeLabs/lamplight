import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// A lit dot in the lamp's real colour.
//
// The colour is read back FROM the lamp rather than predicted from the mode,
// so if the lamp is unreachable or someone changed it in the Govee app, the
// bar shows the truth instead of what we last asked for.
BarWidget {
  id: root
  moduleName: "nixfred.lamplight"
  property var anchorItem: button

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool ready: svc ? svc.ready : false
  readonly property bool reachable: svc ? svc.reachable : false
  readonly property bool lampOn: svc ? svc.lampOn : false
  readonly property string mode: svc ? svc.mode : "theme"

  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return v === undefined ? fallback : v
  }
  readonly property bool showMode: String(setting("showMode", true)) !== "false"
  readonly property bool glow: String(setting("glow", true)) !== "false"

  readonly property color foreground: bar ? bar.foreground : Color.foreground

  // Unreachable or off both mean "no light", and both should read as a dead
  // dot rather than as a colour the lamp is not actually showing.
  readonly property color dotColor: {
    if (!reachable || !lampOn) return Util.alpha(foreground, 0.30)
    var c = svc && svc.lampColor ? svc.lampColor : ""
    return c ? c : Color.accent
  }

  // One unique letter per mode. Two bugs lived here: workspace and weather
  // both returned "W", and any mode missing from the list fell through to
  // "T", so `mix` silently displayed as `theme`. A map makes a collision
  // visible instead of hiding it in a switch default.
  //   S = sun (circadian), C = cloud (weather), X = mix
  readonly property var modeLetters: ({
    "theme": "T", "mix": "X", "ambient": "A", "workspace": "W",
    "circadian": "S", "weather": "C", "events": "E", "music": "M",
    "gauge": "G", "off": "\u2014"
  })
  readonly property string modeLetter: modeLetters[mode] || "?"

  readonly property real contentWidth: Style.space(showMode ? 40 : 24)

  implicitWidth: vertical ? barSize : contentWidth
  implicitHeight: vertical ? contentWidth : barSize

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    // WidgetButton has no contentItem: children go in directly, and this flag
    // is what tells it the widget is showing something despite an empty label.
    hasVisualContent: true
    active: false
    useActiveColor: false
    tooltipText: {
      var info = root.reachable
        ? (root.lampOn ? (svc && svc.lampColor ? svc.lampColor : "on") : "off")
        : "unreachable"
      return "Lamplight \u2014 " + root.mode + " \u2014 " + info
    }

    Row {
      anchors.centerIn: parent
      spacing: Style.space(5)

      Item {
        width: Style.space(18)
        height: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter

        // A plain scaled circle at low opacity, not a blur: a blur on a bar
        // widget repaints every frame and is not worth the GPU at this size.
        Rectangle {
          visible: root.glow && root.reachable && root.lampOn
          anchors.centerIn: parent
          width: parent.width * 1.5
          height: width
          radius: width / 2
          color: root.dotColor
          border.width: 0
          opacity: 0.22
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.6
          height: width
          radius: width / 2
          color: root.dotColor
          // Rectangle border defaults to width 1 even when never set, so an
          // unwanted hairline shows up unless it is pinned to 0.
          border.width: 0
          Behavior on color { ColorAnimation { duration: 400 } }
        }
      }

      Text {
        visible: root.showMode
        anchors.verticalCenter: parent.verticalCenter
        text: root.modeLetter
        color: root.reachable ? root.foreground : Util.alpha(root.foreground, 0.4)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    onPressed: function(code) {
      if (root.bar) root.bar.hideTooltip(root)
      root.toggle()
    }
  }

  readonly property bool opened: panel.opened
  function open() { panel.controller.show(); if (svc) svc.refresh() }
  function close() { panel.controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { close() }
  readonly property bool popoutSwitchClosing: false

  LampPanel {
    id: panel
    widget: root
  }
}
