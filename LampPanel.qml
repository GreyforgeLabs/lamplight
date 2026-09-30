import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Everything on one screen. No Flickable, no ScrollView, nothing that hides a
// control behind a gesture: width is the remedy, never height.
//
// The first cut put the mode grid in two columns beside a tall right-hand rail
// that held one slider, which left a dead column roughly a third of the panel
// wide while the mode descriptions truncated for want of a few pixels. The grid
// now runs the full width at four across, and the controls are full-width rows
// underneath, so nothing is starved and nothing is empty.
//
// There is deliberately NO colour picker. The lamp wears the active Omarchy
// theme, always; the only decision here is what the lamp is DOING.
Panel {
  id: panel
  moduleName: "nixfred.lamplight"
  manageIpc: false

  required property var widget
  readonly property var svc: widget.svc

  readonly property color foreground: widget.bar ? widget.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color faint: Util.alpha(foreground, 0.10)
  readonly property string fontFamily: widget.bar ? widget.bar.fontFamily : Style.font.family

  readonly property string mode: svc ? svc.mode : "theme"
  readonly property bool reachable: svc ? svc.reachable : false

  readonly property var modeInfo: ({
    "theme":     { "title": "Theme",     "blurb": "Rest on the theme's accent colour." },
    "ambient":   { "title": "Ambient",   "blurb": "Fade continuously around the theme's whole palette." },
    "workspace": { "title": "Workspace", "blurb": "Every workspace gets its own colour from the theme." },
    "circadian": { "title": "Circadian", "blurb": "Follow the sun. Cool at midday, warm and dim after dark." },
    "weather":   { "title": "Weather",   "blurb": "Outside temperature, dimmed by cloud cover." },
    "events":    { "title": "Events",    "blurb": "Still, until something happens. Then a brief tint." },
    "music":     { "title": "Music",     "blurb": "React to whatever the JBL speaker is playing." },
    "gauge":     { "title": "Gauge",     "blurb": "A meter, from the theme's colour through to red." },
    "off":       { "title": "Off",       "blurb": "Lamp off." }
  })

  readonly property int panelWidth: Style.space(1180)

  KeyboardPanel {
    id: kpanel
    anchorItem: panel.widget.anchorItem
    owner: panel.widget
    bar: panel.widget.bar
    open: panel.opened
    focusTarget: keyCatcher
    contentWidth: kpanel.fittedContentWidth(panel.panelWidth)
    // Never a Flickable in here: the cap is the screen, and everything inside
    // is sized to fit within it.
    contentHeight: kpanel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: panel.widget.close()

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // ------------------------------------------------------ header
        // The header had a wide gap doing nothing, so the live readout that
        // would otherwise need its own row lives in it.
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(14); height: width; radius: width / 2
            border.width: 0
            color: panel.reachable && svc && svc.lampOn
                   ? (svc.lampColor ? svc.lampColor : Color.accent)
                   : Util.alpha(panel.foreground, 0.3)
            Behavior on color { ColorAnimation { duration: 400 } }
          }

          Text {
            text: "Lamplight"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: panel.reachable
                  ? (svc && svc.lampColor ? svc.lampColor : "")
                  : "unreachable — check LAN Control and udp/4002"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Item { Layout.fillWidth: true }

          Text {
            visible: panel.reachable
            text: (panel.modeInfo[panel.mode] ? panel.modeInfo[panel.mode].title : panel.mode)
                  + "  ·  " + (svc ? svc.brightness : 0) + "%"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Switch {
            checked: svc ? svc.lampOn : false
            onToggled: if (svc) svc.setPower(checked)
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panel.faint; border.width: 0 }

        // ------------------------------------------------------ modes
        // Four across: eight modes in two rows, each tile wide enough that the
        // description reads in full instead of eliding mid-word.
        GridLayout {
          Layout.fillWidth: true
          columns: 3
          columnSpacing: Style.space(10)
          rowSpacing: Style.space(10)

          Repeater {
            model: svc ? svc.modes : []
            delegate: Rectangle {
              required property string modelData
              readonly property bool active: panel.mode === modelData
              readonly property var info: panel.modeInfo[modelData]
                                          || ({ "title": modelData, "blurb": "" })

              Layout.fillWidth: true
              // Equal columns: preferredWidth is a ratio here, not a pixel size.
              Layout.preferredWidth: 1
              implicitHeight: Style.space(72)
              radius: Style.space(8)
              border.width: active ? 2 : 1
              border.color: active ? Color.accent : panel.faint
              color: active ? Util.alpha(Color.accent, 0.14) : "transparent"

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(9)
                spacing: Style.space(2)

                Text {
                  text: info.title
                  color: panel.foreground
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: active
                }
                Text {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  text: info.blurb
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                  color: panel.dim
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              // Pointer handlers do not fire reliably inside these panels;
              // MouseArea is the one that works.
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (svc) svc.setMode(modelData)
              }
            }
          }
        }

        // ------------------------------------------------------ brightness
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: "Brightness"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Slider {
            id: bright
            Layout.fillWidth: true
            from: 1; to: 100; stepSize: 1
            // Dragging a Slider assigns `value` imperatively, which destroys a
            // plain `value:` binding for good -- the handle would then ignore
            // every later poll, so CLI changes and circadian's dimming stopped
            // showing. A Binding gated on `pressed` survives the drag.
            Binding on value {
              when: !bright.pressed
              value: svc ? Math.max(1, svc.brightness) : 50
              restoreMode: Binding.RestoreBinding
            }
            onPressedChanged: if (!pressed && svc) svc.setBrightness(Math.round(value))
          }
          Text {
            text: Math.round(bright.value) + "%"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        // ------------------------------------------------- per-mode controls
        // Only rendered for the mode they belong to. A row that collapses is
        // better than a rail that stays empty for six modes out of eight.
        // Ambient is the one mode with a speed worth tuning, so it gets the
        // same collapsing-row treatment as the gauge source.
        RowLayout {
          visible: panel.mode === "ambient"
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: "Cycle"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Slider {
            id: cycle
            Layout.fillWidth: true
            from: svc ? svc.ambientCycleMin : 5
            to: svc ? svc.ambientCycleMax : 60
            stepSize: 1
            Binding on value {
              when: !cycle.pressed
              value: svc ? svc.ambientCycle : 15
              restoreMode: Binding.RestoreBinding
            }
            // Commit on release, not on every pixel of the drag: each commit
            // rewrites the config the running effect re-reads each lap.
            onPressedChanged: if (!pressed && svc) svc.setAmbientCycle(Math.round(value))
          }
          Text {
            text: Math.round(cycle.value) + "s a lap"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        RowLayout {
          visible: panel.mode === "workspace"
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: "Workspace"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Row {
            id: wsRow
            Layout.fillWidth: true
            readonly property int count: svc && svc.palette ? svc.palette.length : 0
            spacing: 2
            Repeater {
              model: wsRow.count
              delegate: Rectangle {
                required property int index
                readonly property bool here: svc && ((svc.workspace - 1) % wsRow.count) === index
                width: wsRow.count > 0
                       ? Math.max(Style.space(22),
                                  (wsRow.width - (wsRow.count - 1) * 2) / wsRow.count)
                       : Style.space(22)
                height: Style.space(18)
                radius: 3
                color: svc.palette[index]
                // The live workspace is called out with a ring rather than a
                // different colour, so the mapping itself stays readable.
                border.width: here ? 2 : 0
                border.color: panel.foreground
                Text {
                  anchors.centerIn: parent
                  text: index + 1
                  color: "#000000"
                  opacity: 0.55
                  font.family: panel.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: parent.here
                }
              }
            }
          }
        }

        RowLayout {
          visible: panel.mode === "gauge"
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: "Measuring"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Repeater {
            model: svc ? svc.gaugeSources : []
            delegate: Rectangle {
              required property string modelData
              readonly property bool sel: svc && svc.gaugeSource === modelData
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: Style.space(6)
              border.width: 1
              border.color: sel ? Color.accent : panel.faint
              color: sel ? Util.alpha(Color.accent, 0.16) : "transparent"
              Text {
                anchors.centerIn: parent
                text: modelData
                color: panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (svc) svc.run([svc.cli, "gauge-source", modelData])
              }
            }
          }
        }

        RowLayout {
          visible: panel.mode === "events"
          Layout.fillWidth: true
          spacing: Style.space(8)

          Text {
            text: "Test a tint"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Repeater {
            model: ["ok", "warn", "fail", "info"]
            delegate: Rectangle {
              required property string modelData
              Layout.fillWidth: true
              implicitHeight: Style.space(28)
              radius: Style.space(6)
              border.width: 1
              border.color: panel.faint
              color: "transparent"
              Text {
                anchors.centerIn: parent
                text: modelData
                color: panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (svc) svc.flash(modelData)
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panel.faint; border.width: 0 }

        // ------------------------------------------------------ theme ribbon
        // Not a picker. It shows WHERE the colour comes from, which is the
        // whole contract: the lamp wears the theme, you choose the behaviour.
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: "Carrying theme"
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            text: svc ? svc.themeName : ""
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          // The swatches stretch to fill whatever the label leaves, so the
          // ribbon reads as one continuous band instead of a stub.
          Row {
            id: ribbon
            Layout.fillWidth: true
            readonly property int count: svc && svc.palette ? svc.palette.length : 0
            spacing: 2
            Repeater {
              model: svc ? svc.palette : []
              delegate: Rectangle {
                required property string modelData
                width: ribbon.count > 0
                       ? Math.max(Style.space(14),
                                  (ribbon.width - (ribbon.count - 1) * 2) / ribbon.count)
                       : Style.space(14)
                height: Style.space(10)
                radius: 2
                border.width: 0
                color: modelData
              }
            }
          }
        }
      }
    }
  }
}
