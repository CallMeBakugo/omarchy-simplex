import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SimpleX Chat bar chip. The desktop app has no Wayland tray, so the chip IS
// the tray: left click launches the app or toggles its window between the
// current view and Hyprland's special:simplex workspace (hidden, still
// running). All window plumbing lives in simplex-toggle.sh, shipped next to
// this file.
Panel {
  id: root
  moduleName: "bakugo.simplex"
  ipcTarget: "bakugo.simplex"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color statusColor: up ? "#50fa7b" : foreground

  property bool up: false

  // Settings (with safe fallbacks - manifest defaults are not auto-merged).
  readonly property string appPath: {
    var p = String(root.setting("appPath", "")).trim()
    return p
  }
  readonly property string windowClass: {
    var c = String(root.setting("windowClass", "")).trim()
    return c !== "" ? c : "chat-simplex-desktop-MainKt"
  }
  readonly property string toggleScript: {
    var u = String(Qt.resolvedUrl("simplex-toggle.sh"))
    return u.startsWith("file://") ? decodeURIComponent(u.slice(7)) : u
  }

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: poll
    running: false
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const clients = JSON.parse(text)
          root.up = clients.some(client =>
            client.class === root.windowClass || client.initialClass === root.windowClass)
        } catch (error) {
          root.up = false
        }
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!poll.running) poll.running = true
  }

  function toggleApp() {
    Quickshell.execDetached([root.toggleScript, root.appPath, root.windowClass])
    // Optimistic flip; poll corrects within 5 s (or right-click).
    Qt.callLater(function() { if (!poll.running) poll.running = true })
  }

  IpcHandler {
    target: root.ipcTarget
    function toggle(): void { root.toggleApp() }
    function refresh(): string {
      if (!poll.running) poll.running = true
      return "ok"
    }
  }

  // ---- bar chip ----------------------------------------------------------

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    tooltipText: root.up
      ? "SimpleX Chat running • click to show or hide"
      : "SimpleX Chat closed • click to launch"

    // Omarchy can forward presses from its bar-level hit test. Only act
    // when this instance actually has the pointer on its own button.
    HoverHandler {
      id: pointerOverButton
      blocking: false
    }

    onPressed: function(buttonCode) {
      if (!pointerOverButton.hovered) return
      if (buttonCode === Qt.LeftButton) root.toggleApp()
      else if (buttonCode === Qt.RightButton && !poll.running) poll.running = true
    }

    BorderSurface {
      anchors.centerIn: parent
      width: Style.bar.iconSize
      height: width
      radius: width / 2
      scale: button.pressScale
      color: root.alpha(root.statusColor, root.up ? 0.12 : 0.08)
      borderSpec: Border.flat(root.alpha(root.statusColor, 0.58), 1)

      Image {
        id: appMark
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.83)
        height: width
        source: "file:///opt/simplex/lib/simplex.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        opacity: root.up ? 1 : 0.72
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: !appMark.visible
        text: "SX"
        textFormat: Text.PlainText
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: 12
        font.bold: true
      }
    }
  }
}
