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
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Green when the app runs in the background, red/urgent only when closed.
  readonly property color statusColor: up ? "#50fa7b" : urgent

  property bool up: false

  // Settings (with safe fallbacks - manifest defaults are not auto-merged).
  readonly property string appPath: {
    var p = String(root.setting("appPath", "")).trim()
    return p !== "" ? p : (Quickshell.env("HOME") + "/simplex")
  }
  readonly property string windowClass: {
    var c = String(root.setting("windowClass", "")).trim()
    return c !== "" ? c : "chat-simplex-desktop-MainKt"
  }
  readonly property string appName: {
    var n = appPath.split("/").pop()
    return n.replace(/[^A-Za-z0-9._-]/g, "")
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
    command: ["sh", "-c", "pgrep -x '" + root.appName + "' >/dev/null 2>&1 && echo up || echo down"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.up = String(text).trim() === "up"
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

  BorderSurface {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: Style.space(18)
    radius: Math.min(Style.cornerRadius, height / 2)
    color: root.up ? root.alpha(root.statusColor, 0.12) : root.alpha(root.urgent, 0.14)
    borderSpec: Border.flat(
      root.up ? root.alpha(root.statusColor, 0.55) : root.alpha(root.urgent, 0.55), 1)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: Style.space(36)
    text: "SX"
    foreground: root.statusColor
    active: false
    useActiveColor: false
    fontSize: Style.font.caption
    horizontalMargin: 7
    verticalPadding: 5
    tooltipText: root.up
      ? "SimpleX Chat running - click to show or hide"
      : "SimpleX Chat closed - click to launch"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (!poll.running) poll.running = true
      } else {
        root.toggleApp()
      }
    }
  }
}