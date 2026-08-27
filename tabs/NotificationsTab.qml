import QtQuick
import qs.Commons
import qs.Ui
import "../" // Picker
import "../Strings.js" as Strings

// Tab 4: master on/off, per-category notification toggles, notification
// scope, UI language, and the two poll-interval settings.
Item {
  id: root

  property var service: null
  property var hostWidget: null   // the BarWidget instance; owns saveSetting()
  property string language: "en"
  property string footballName: "soccer"
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property var notif: service ? service.notifications : ({})
  readonly property bool notifEnabled: notif.enabled === true

  // Natural height of this tab's content, unclamped by the viewport —
  // Panel.qml reads this to size the tab area to whichever tab is active
  // instead of a fixed height that leaves empty space under short tabs.
  readonly property real contentHeight: column.implicitHeight

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Style.space(10)

      Toggle {
        width: parent.width
        label: Strings.t(root.language, "notifMaster")
        checked: root.notifEnabled
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: if (root.service) root.service.setNotifPref("enabled", !root.notifEnabled)
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        opacity: root.notifEnabled ? 1.0 : 0.4
        enabled: root.notifEnabled

        Toggle {
          width: parent.width
          label: Strings.t(root.language, "notifGoals")
          checked: root.notif.goals === true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.setNotifPref("goals", !root.notif.goals)
        }
        Toggle {
          width: parent.width
          label: Strings.t(root.language, "notifImportant")
          checked: root.notif.important === true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.setNotifPref("important", !root.notif.important)
        }
        Toggle {
          width: parent.width
          label: Strings.t(root.language, "notifScoreChange")
          checked: root.notif.scoreChange === true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.setNotifPref("scoreChange", !root.notif.scoreChange)
        }
        Toggle {
          width: parent.width
          label: Strings.t(root.language, "notifMatchStatus")
          checked: root.notif.matchStatus === true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.setNotifPref("matchStatus", !root.notif.matchStatus)
        }

        Picker {
          width: parent.width
          label: Strings.t(root.language, "notifScope")
          options: [
            { value: "teams", label: Strings.t(root.language, "notifScopeTeams") },
            { value: "leagues", label: Strings.t(root.language, "notifScopeLeagues") }
          ]
          value: root.notif.scope || "teams"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onChanged: function(v) { if (root.service) root.service.setNotifPref("scope", v) }
        }
      }

      PanelSeparator { foreground: root.foreground }

      Picker {
        width: parent.width
        label: Strings.t(root.language, "language")
        options: [
          { value: "en", label: "English" },
          { value: "fr", label: "Français" },
          { value: "es", label: "Español" }
        ]
        value: root.language
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("language", v) }
      }

      Picker {
        width: parent.width
        label: Strings.t(root.language, "footballNameLabel")
        options: [
          { value: "soccer", label: Strings.footballName(root.language, "soccer") },
          { value: "football", label: Strings.footballName(root.language, "football") },
          { value: "european_football", label: Strings.footballName(root.language, "european_football") }
        ]
        value: root.footballName
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("footballName", v) }
      }

      Toggle {
        width: parent.width
        label: Strings.t(root.language, "showScoreInBar")
        checked: root.service ? root.service.compactBarLabel : true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: if (root.hostWidget && root.service) root.hostWidget.saveSetting("compactBarLabel", !root.service.compactBarLabel)
      }

      Picker {
        width: parent.width
        label: Strings.t(root.language, "heroWidgetLabel")
        options: [
          { value: "trophy", label: Strings.t(root.language, "heroWidgetTrophy") },
          { value: "scoreboard", label: Strings.t(root.language, "heroWidgetScoreboard") }
        ]
        value: root.service ? root.service.heroWidget : "trophy"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("heroWidget", v) }
      }

      NumberField {
        width: parent.width
        label: Strings.t(root.language, "idleRefreshRate")
        value: root.service ? root.service.refreshIntervalSec : 20
        from: 10
        to: 120
        stepSize: 5
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("refreshIntervalSec", v) }
      }

      NumberField {
        width: parent.width
        label: Strings.t(root.language, "liveRefreshRate")
        value: root.service ? root.service.liveRefreshIntervalSec : 5
        from: 3
        to: 30
        stepSize: 1
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("liveRefreshIntervalSec", v) }
      }

      NumberField {
        width: parent.width
        label: Strings.t(root.language, "standingsRefreshRate")
        value: root.service ? root.service.scheduleRefreshIntervalMin : 5
        from: 1
        to: 60
        stepSize: 1
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(v) { if (root.hostWidget) root.hostWidget.saveSetting("scheduleRefreshIntervalMin", v) }
      }
    }
  }
}
