import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Strings.js" as Strings
import "tabs" as Tabs

// The live-scores panel: a hero, a home-made tab row (no TabBar component
// ships with the shell's Ui kit), and four tab views kept alive together
// so switching tabs never loses state (the selected league in Standings,
// scroll position in Direct, etc).
Panel {
  id: root
  moduleName: "krakeneyes.live-scores"
  ipcTarget: "krakeneyes.live-scores"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var scores: null

  // The bar tracks the widget in its slot, not this nested panel, so
  // anything the popout coordinator compares against has to be the widget.
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string language: scores ? scores.language : "en"
  readonly property string footballName: scores ? scores.footballName : "soccer"
  readonly property string heroWidget: scores ? scores.heroWidget : "trophy"

  readonly property var tabs: [
    { id: "live", label: Strings.t(root.language, "tabLive") },
    { id: "standings", label: Strings.t(root.language, "tabStandings") },
    { id: "follow", label: Strings.t(root.language, "tabFollow") },
    { id: "notifications", label: Strings.t(root.language, "tabNotifications") }
  ]
  property string currentTab: "live"

  // Hero icon components, picked by the `heroWidget` setting (default
  // "trophy" keeps today's static icon; "scoreboard" swaps in the
  // click-to-expand score/countdown widget — see HeroMatchWidget.qml).
  Component {
    id: heroTrophyComponent
    Text {
      text: Model.GLYPH_TROPHY
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
    }
  }

  Component {
    id: heroMatchWidgetComponent
    HeroMatchWidget {
      service: root.scores
      foreground: root.foreground
      fontFamily: root.fontFamily
      language: root.language
    }
  }

  function open() {
    root.controller.show()
    if (scores) scores.refreshScoreboards()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openFromHotkey() { open() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { if (root.scores) root.scores.refreshScoreboards(); return "ok" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        var idx = 0
        for (var i = 0; i < root.tabs.length; i++) if (root.tabs[i].id === root.currentTab) idx = i
        idx = (idx + direction + root.tabs.length) % root.tabs.length
        root.currentTab = root.tabs[idx].id
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: Strings.t(root.language, "heroTitle")
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: root.heroWidget === "scoreboard" ? heroMatchWidgetComponent : heroTrophyComponent
        }

        // Flow (not Row) so a tab label that doesn't fit wraps to the next
        // line instead of overflowing the panel's right edge — French and
        // Spanish labels run noticeably longer than English ones.
        Flow {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.tabs
            delegate: Button {
              required property var modelData
              text: modelData.label
              selected: root.currentTab === modelData.id
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              horizontalPadding: Style.space(8)
              onClicked: root.currentTab = modelData.id
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        Item {
          width: parent.width
          height: Style.space(360)

          Tabs.LiveTab {
            anchors.fill: parent
            visible: root.currentTab === "live"
            service: root.scores
            language: root.language
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Tabs.StandingsTab {
            anchors.fill: parent
            visible: root.currentTab === "standings"
            service: root.scores
            language: root.language
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Tabs.FollowTab {
            anchors.fill: parent
            visible: root.currentTab === "follow"
            service: root.scores
            language: root.language
            footballName: root.footballName
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Tabs.NotificationsTab {
            anchors.fill: parent
            visible: root.currentTab === "notifications"
            service: root.scores
            hostWidget: root.hostWidget
            language: root.language
            footballName: root.footballName
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
        }
      }
    }
  }
}
