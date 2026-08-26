import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui

// Single-select dropdown, built in-house instead of qs.Ui's Dropdown.
//
// Why: Dropdown's QQC.Popup has no closePolicy override, so clicking the
// trigger while the popup is open first triggers the popup's own
// click-outside dismissal (the press lands "outside" the popup's own
// bounds), and only *then* does the trigger's MouseArea.onClicked fire --
// reading `popup.opened` as already false and reopening it. Net effect:
// clicking an open dropdown's trigger never closes it. `_suppressReopen`
// below is the standard fix for that exact Qt Quick Controls interaction:
// a short guard window after the popup closes itself, during which a
// trigger click is treated as "the outside-press that just closed this",
// not as a fresh open request.
//
// The popup reparents to the window's content item (same as
// SearchableDropdown/MultiSelect) so it is never clipped by an ancestor
// Flickable, and its own row height is sized off the font, not a fixed
// constant, so labels never clip against their box.
Item {
  id: root

  property string label: ""
  property string value: ""
  property var options: []          // [{ value, label }]
  property string placeholderText: ""
  property bool showLabel: true

  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color popupBorder: Color.popups.border
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal changed(string value)

  function optionLabel(v) {
    for (var i = 0; i < options.length; i++) if (String(options[i].value) === v) return options[i].label
    return v
  }

  readonly property int rowHeight: Math.round(Style.font.body * 2.3)
  readonly property int popupRowHeight: Math.round(Style.font.body * 2.3)

  implicitWidth: Style.space(220)
  implicitHeight: (showLabel && label !== "" ? rowHeight + Style.spacing.labelGap + Style.font.caption : rowHeight)

  property bool _suppressReopen: false
  Timer { id: reopenGuard; interval: 250; onTriggered: root._suppressReopen = false }

  function toggle() {
    if (root._suppressReopen) return
    popup.visible ? popup.close() : popup.open()
  }

  Column {
    anchors.fill: parent
    spacing: Style.spacing.labelGap

    Text {
      textFormat: Text.PlainText
      visible: root.showLabel && root.label !== ""
      text: root.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    BorderSurface {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Style.cornerRadius
      color: Style.controlFill(false, triggerHover.hovered, root.foreground, root.accent)
      borderSpec: Border.controlSpec(triggerHover.hovered ? "hover-cursor" : "normal", root.foreground, root.accent)

      HoverHandler { id: triggerHover }

      Text {
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.spacing.controlPaddingX
        anchors.rightMargin: Style.spacing.md
        text: root.value !== "" ? root.optionLabel(root.value) : root.placeholderText
        color: root.value !== "" ? root.foreground : Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Style.spacing.controlGap
        text: popup.visible ? "󰅃" : "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
      }
    }
  }

  QQC.Popup {
    id: popup
    parent: trigger.Window.window ? trigger.Window.window.contentItem : trigger

    property real _anchorX: 0
    property real _anchorY: 0

    function reposition() {
      if (!parent) return
      var p = trigger.mapToItem(parent, 0, trigger.height + Style.spacing.xxs)
      _anchorX = p.x
      _anchorY = p.y
    }

    x: _anchorX
    y: _anchorY
    width: trigger.width
    height: Math.min(Math.max(root.options.length, 1), 7) * root.popupRowHeight + Style.space(16)
    padding: Style.spacing.hairline
    focus: true

    Connections {
      target: trigger
      function onXChanged() { popup.reposition() }
      function onYChanged() { popup.reposition() }
      function onWidthChanged() { popup.reposition() }
      function onHeightChanged() { popup.reposition() }
    }

    onOpened: reposition()
    onClosed: { root._suppressReopen = true; reopenGuard.restart() }

    background: BorderSurface {
      color: root.background
      borderSpec: Border.surfaceSpec("popups", "border", root.popupBorder, Style.normalBorderWidth)
      radius: Style.cornerRadius
    }

    contentItem: ListView {
      id: listView
      clip: true
      model: root.options
      boundsBehavior: Flickable.StopAtBounds
      QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

      delegate: Rectangle {
        id: row
        required property var modelData
        width: listView.width
        height: root.popupRowHeight
        color: hover.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.spacing.controlPaddingX
          anchors.rightMargin: Style.spacing.controlPaddingX
          text: row.modelData.label
          color: String(row.modelData.value) === root.value ? root.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        HoverHandler { id: hover }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.value = String(row.modelData.value)
            root.changed(root.value)
            popup.close()
          }
        }
      }
    }
  }
}
