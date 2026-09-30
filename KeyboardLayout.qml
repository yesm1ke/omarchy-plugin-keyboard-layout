import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "file:///usr/share/omarchy/shell/plugins/bar/widgets" as Stock
import "LayoutNames.js" as LayoutNames

// The stock keyboard-layout widget plus two things of our own. Nothing is
// copied: Stock.KeyboardLayout is the packaged omarchy.keyboard-layout widget
// (label, keyboard detection, polling), so Omarchy updates to it apply here
// automatically. This file adds:
//   1. switching the whole seat ("all") instead of one device, and
//   2. a popup with the configured layouts (right click, or the panel hotkey).
Stock.KeyboardLayout {
  id: wrapper

  // Panel-hotkey contract (SUPER+CTRL+1-9 / Bar.qml:findPanelWidget): a widget
  // only gets a slot number if it exposes open()/close()/opened. The stock
  // widget has no popup at all, so these are additions.
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  function open() { popupOpen = true }
  function close() { popupOpen = false }

  // Keyboard navigation inside the popup. PopupCard (xdg-popup) never gets key
  // events unless a click already routed focus through the parent surface, so
  // Escape/arrows would do nothing when the popup is opened by hotkey;
  // KeyboardPanel below grabs focus on open instead. The cursor moves over the
  // configured layout list, one entry per layout in kb_layout.
  property bool cursorActive: false
  property int cursorIndex: 0

  // Description per bare layout code ("us" -> "English (US)").
  property var layoutCodeDescriptions: ({})
  property bool layoutNamesRequested: false
  // The configured layout list and which entry is active.
  property string layoutCodes: ""
  property int activeLayoutIndex: -1
  readonly property var layoutList: layoutCodes ? layoutCodes.split(",") : []

  function moveCursor(dx, dy) {
    cursorActive = true
    var n = wrapper.layoutList.length
    if (n <= 0) return
    var delta = dy !== 0 ? dy : dx
    cursorIndex = ((cursorIndex + delta) % n + n) % n
  }

  function activateCursor() {
    cursorActive = true
    wrapper.switchToLayout(cursorIndex)
  }

  // Overrides the stock function, which targets a single device
  // (root.keyboardName). That breaks with fcitx5 running: its virtual
  // keyboard holds the seat's main flag, so switching one physical device
  // leaves fcitx5 (the device actually producing keystrokes) on the old
  // layout. The widget then reads back the physical device's state, which did
  // change, so the label advances while typing doesn't. Target "all" so the
  // whole seat -- fcitx5 included -- moves in lockstep.
  function cycleLayout() {
    if (!wrapper.keyboardName || !wrapper.bar) return
    wrapper.bar.run("hyprctl switchxkblayout all next")
    rereadTimer.restart()
  }

  function switchToLayout(index) {
    if (!wrapper.bar || index < 0 || index >= wrapper.layoutList.length) return
    wrapper.bar.run("hyprctl switchxkblayout all " + index)
    rereadTimer.restart()
  }

  function readLayoutState() {
    if (!stateProc.running) stateProc.running = true
  }

  onPopupOpenChanged: {
    if (!popupOpen) return
    cursorActive = false
    cursorIndex = Math.max(0, wrapper.activeLayoutIndex)
    readLayoutState()
    if (!layoutNamesRequested) {
      layoutNamesRequested = true
      namesProc.running = true
    }
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  // The stock widget updates layoutFull whenever the active layout changes;
  // follow it so the popup's active row stays right.
  onLayoutFullChanged: readLayoutState()

  // Same delay the stock widget uses before re-reading after a switch.
  Timer {
    id: rereadTimer
    interval: 600
    onTriggered: {
      wrapper.refresh()
      wrapper.readLayoutState()
    }
  }

  Process {
    id: stateProc
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var state = LayoutNames.layoutState(text, wrapper.keyboardName)
        if (!state) return
        wrapper.layoutCodes = state.codes
        wrapper.activeLayoutIndex = state.index
      }
    }
  }

  Process {
    id: namesProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: wrapper.layoutCodeDescriptions = LayoutNames.layoutCodeMap(text)
    }
  }

  // The stock button cycles on any mouse button. Take the right one here, on
  // top of it, for the popup; left clicks fall through to the stock button.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onPressed: wrapper.popupOpen = !wrapper.popupOpen
  }

  KeyboardPanel {
    id: popup
    anchorItem: wrapper
    bar: wrapper.bar
    owner: wrapper
    open: wrapper.popupOpen
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(260))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { wrapper.moveCursor(dx, dy) }
      onActivateRequested: wrapper.activateCursor()
      onCloseRequested: wrapper.close()

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(4)

        Repeater {
          model: wrapper.layoutList

          BorderSurface {
            id: layoutRow
            required property string modelData
            required property int index

            readonly property string code: modelData
            readonly property string description: wrapper.layoutCodeDescriptions[code] || code.toUpperCase()
            readonly property bool active: index === wrapper.activeLayoutIndex
            readonly property bool cursorHere: wrapper.cursorActive && wrapper.cursorIndex === index

            width: column.width
            height: rowInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: active ? Style.selectedFillFor(wrapper.bar.foreground, Color.accent) : "transparent"
            borderSpec: active ? Border.controlSpec("normal", wrapper.bar.foreground, Color.accent)
              : (cursorHere ? Border.controlSpec("focus", wrapper.bar.foreground, Color.accent) : Border.none())

            Row {
              id: rowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: layoutRow.borderLeft + Style.space(8)
              anchors.rightMargin: layoutRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: layoutRow.description
                color: wrapper.bar.foreground
                font.family: wrapper.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: layoutRow.active
                elide: Text.ElideRight
                width: parent.width - codeLabel.implicitWidth - Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: codeLabel
                textFormat: Text.PlainText
                text: layoutRow.code
                color: Qt.darker(wrapper.bar.foreground, 1.4)
                font.family: wrapper.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: wrapper.switchToLayout(layoutRow.index)
            }
          }
        }
      }
    }
  }
}
