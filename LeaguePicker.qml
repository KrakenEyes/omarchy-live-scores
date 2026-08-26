import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import qs.Commons
import qs.Ui

// Searchable multi-select checklist, built in-house instead of qs.Ui's
// MultiSelect -- same reopen-on-click bug and fix as Picker.qml (see its
// header comment), plus font-driven row sizing so labels never clip
// against their box regardless of language (French/Spanish labels run
// longer than English ones).
//
// `values` is the persisted selection: always an array of strings.
Item {
  id: root

  property string label: ""
  property var values: []
  property var options: []          // [{ value, label }]
  property string placeholderText: ""
  property string emptyText: ""
  property string noSelectionText: ""
  property string selectedSuffix: "selected"
  property bool showLabel: true

  property color foreground: Color.popups.text
  property color background: Color.popups.background
  property color popupBorder: Color.popups.border
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal changed(var values)

  function arrayFrom(v) {
    if (!v || typeof v.length !== "number" || typeof v === "string") return []
    var out = []
    for (var i = 0; i < v.length; i++) out.push(v[i])
    return out
  }

  function isSelected(value) { return root.arrayFrom(root.values).indexOf(String(value)) !== -1 }

  function toggleValue(value) {
    var v = String(value)
    var arr = root.arrayFrom(root.values)
    var idx = arr.indexOf(v)
    if (idx === -1) arr.push(v); else arr.splice(idx, 1)
    root.values = arr
    root.changed(arr)
  }

  function selectionLabel() {
    var arr = root.arrayFrom(root.values)
    if (arr.length === 0) return ""
    var byValue = ({})
    for (var i = 0; i < root.options.length; i++) byValue[String(root.options[i].value)] = root.options[i].label
    if (arr.length <= 2) {
      var labels = []
      for (var j = 0; j < arr.length; j++) labels.push(byValue[arr[j]] || arr[j])
      return labels.join(", ")
    }
    return arr.length + " " + root.selectedSuffix
  }

  property var filtered: root.options
  function recomputeFiltered() {
    var q = searchField.text.toLowerCase()
    if (!q) { root.filtered = root.options; return }
    var out = []
    for (var i = 0; i < root.options.length; i++) {
      if (String(root.options[i].label).toLowerCase().indexOf(q) !== -1) out.push(root.options[i])
    }
    root.filtered = out
  }
  onOptionsChanged: recomputeFiltered()

  readonly property int rowHeight: Math.round(Style.font.body * 2.3)
  readonly property int popupRowHeight: Math.round(Style.font.body * 2.4)

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
        text: root.selectionLabel() || root.placeholderText || root.noSelectionText
        color: root.selectionLabel() ? root.foreground : Qt.darker(root.foreground, 1.5)
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
    height: Math.min(Math.max(root.options.length, 1), 6) * root.popupRowHeight
      + root.popupRowHeight /* search row */ + Style.space(16)
    padding: Style.spacing.hairline
    focus: true

    Connections {
      target: trigger
      function onXChanged() { popup.reposition() }
      function onYChanged() { popup.reposition() }
      function onWidthChanged() { popup.reposition() }
      function onHeightChanged() { popup.reposition() }
    }

    onOpened: {
      reposition()
      searchField.text = ""
      root.recomputeFiltered()
      Qt.callLater(function() { searchField.forceActiveFocus() })
    }
    onClosed: { root._suppressReopen = true; reopenGuard.restart() }

    background: BorderSurface {
      color: root.background
      borderSpec: Border.surfaceSpec("popups", "border", root.popupBorder, Style.normalBorderWidth)
      radius: Style.cornerRadius
    }

    contentItem: Column {
      spacing: 0

      TextField {
        id: searchField
        width: parent.width
        height: root.popupRowHeight
        placeholderText: root.placeholderText
        foreground: root.foreground
        accent: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        onTextChanged: root.recomputeFiltered()
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
      }

      Item {
        width: parent.width
        height: popup.height - searchField.height - 1 - Style.space(16)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: listView.count === 0
          text: root.emptyText
          color: Qt.darker(root.foreground, 1.6)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        ListView {
          id: listView
          anchors.fill: parent
          clip: true
          model: root.filtered
          boundsBehavior: Flickable.StopAtBounds
          QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool selected: root.isSelected(row.modelData.value)
            width: listView.width
            height: root.popupRowHeight
            color: hover.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.spacing.controlPaddingX
              spacing: Style.spacing.rowGap

              BorderSurface {
                id: checkbox
                width: Style.space(15)
                height: Style.space(15)
                radius: Math.max(2, Style.cornerRadius / 2)
                anchors.verticalCenter: parent.verticalCenter
                color: row.selected ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
                borderSpec: Border.controlSpec(row.selected ? "selected" : "normal", root.foreground, root.accent)

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: row.selected
                  text: "✓"
                  color: Style.selectedStateColor(root.foreground, root.accent)
                  font.family: root.fontFamily
                  font.pixelSize: Math.round(checkbox.height * 0.8)
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width - checkbox.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                color: row.selected ? root.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            HoverHandler { id: hover }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleValue(row.modelData.value)
            }
          }
        }
      }
    }
  }
}
