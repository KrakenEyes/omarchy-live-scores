import QtQuick
import qs.Commons
import qs.Ui
import "../" // Picker, LeaguePicker
import "../Sports.js" as Sports
import "../Strings.js" as Strings

// Tab 3: pick which leagues to follow (grouped by sport), add a custom
// ESPN league slug when a league isn't in the curated catalogue, and — per
// followed head-to-head league — optionally narrow it down to specific
// teams. Leaderboard leagues (golf, motorsport, combat) have no team
// concept, so they skip the team picker entirely.
Item {
  id: root

  property var service: null
  property string language: "en"
  property string footballName: "soccer"
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  function sportGroupLabel(sportId) {
    if (sportId === "soccer") return Strings.footballName(root.language, root.footballName)
    return Strings.t(root.language, "sportGroup_" + sportId)
  }

  function slugsForGroup(group) {
    var out = []
    for (var i = 0; i < group.leagues.length; i++) out.push(group.leagues[i].slug)
    return out
  }

  function selectedForGroup(group) {
    var followed = service ? service.followedLeagues : []
    var slugs = slugsForGroup(group)
    var out = []
    for (var i = 0; i < followed.length; i++) if (slugs.indexOf(followed[i]) !== -1) out.push(followed[i])
    return out
  }

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
      spacing: Style.space(16)

      PanelSectionHeader {
        text: Strings.t(root.language, "followedLeagues")
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: Sports.SPORTS
        delegate: Column {
          id: sportBlock
          required property var modelData
          width: column.width
          spacing: Style.space(4)

          Text {
            textFormat: Text.PlainText
            text: root.sportGroupLabel(sportBlock.modelData.id)
            color: Qt.darker(root.foreground, 1.3)
            font.bold: true
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          LeaguePicker {
            width: sportBlock.width
            showLabel: false
            options: {
              var out = []
              for (var i = 0; i < sportBlock.modelData.leagues.length; i++)
                out.push({ value: sportBlock.modelData.leagues[i].slug, label: sportBlock.modelData.leagues[i].name })
              return out
            }
            values: root.selectedForGroup(sportBlock.modelData)
            foreground: root.foreground
            fontFamily: root.fontFamily
            placeholderText: Strings.t(root.language, "searchPlaceholder")
            emptyText: Strings.t(root.language, "noOptions")
            noSelectionText: Strings.t(root.language, "selectLeague")
            selectedSuffix: Strings.t(root.language, "selectedSuffix")
            onChanged: function(vals) { if (root.service) root.service.setLeaguesForSport(sportBlock.modelData.id, vals) }
          }
        }
      }

      PanelSeparator { foreground: root.foreground }

      Row {
        width: column.width
        spacing: Style.space(8)

        TextField {
          id: customSlugField
          width: Math.max(Style.space(60), column.width - addButton.width - parent.spacing)
          placeholderText: Strings.t(root.language, "customLeague")
          foreground: root.foreground
        }

        Button {
          id: addButton
          text: Strings.t(root.language, "addLeague")
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: {
            if (root.service && customSlugField.text.trim() !== "") {
              root.service.addCustomLeague(customSlugField.text.trim())
              customSlugField.text = ""
            }
          }
        }
      }

      PanelSeparator {
        foreground: root.foreground
        visible: (root.service ? root.service.followedLeagues.length : 0) > 0
      }

      Text {
        textFormat: Text.PlainText
        visible: (root.service ? root.service.followedLeagues.length : 0) > 0
        width: column.width
        text: Strings.t(root.language, "followedTeams")
        color: Qt.darker(root.foreground, 1.3)
        wrapMode: Text.WordWrap
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Repeater {
        model: root.service ? root.service.followedLeagues : []
        delegate: Column {
          id: teamBlock
          required property string modelData
          readonly property bool leaderboard: Sports.leagueKind(modelData) === "leaderboard"
          readonly property bool olympics: root.service ? root.service.isOlympicLeague(modelData) : false
          width: column.width
          spacing: Style.space(4)
          visible: !leaderboard && !olympics

          // Team data is fetched regardless of whether this league renders
          // its own picker below: Olympic leagues need it too, to build the
          // cross-sport country picker further down.
          Component.onCompleted: if (root.service && !leaderboard) root.service.ensureTeams(teamBlock.modelData)

          Row {
            width: teamBlock.width
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: Sports.leagueLabel(teamBlock.modelData)
              color: Qt.darker(root.foreground, 1.2)
              font.bold: true
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              text: "· " + Strings.t(root.language, "removeLeague")
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.removeLeague(teamBlock.modelData)
              }
            }
          }

          LeaguePicker {
            width: teamBlock.width
            showLabel: false
            options: (root.service && root.service.teamsByLeague[teamBlock.modelData])
              ? root.service.teamsByLeague[teamBlock.modelData].map(function(t) { return { value: t.id, label: t.name } })
              : []
            values: root.service ? root.service.teamIdsForLeague(teamBlock.modelData) : []
            foreground: root.foreground
            fontFamily: root.fontFamily
            placeholderText: Strings.t(root.language, "searchPlaceholder")
            emptyText: Strings.t(root.language, "noOptions")
            noSelectionText: Strings.t(root.language, "followedTeams")
            selectedSuffix: Strings.t(root.language, "selectedSuffix")
            onChanged: function(vals) { if (root.service) root.service.setTeamsForLeague(teamBlock.modelData, vals) }
          }
        }
      }

      PanelSeparator { foreground: root.foreground }

      // The Olympics have no curated league list (see Sports.js): ESPN
      // only exposes them per-sport, only during that edition's Games, with
      // no naming consistent enough to hardcode. This is a general "track
      // whatever event is live + filter by country" section instead of a
      // per-sport picker — "teams" there are national teams, so one
      // cross-sport country filter covers every Olympic league followed at
      // once, rather than reconfiguring per sport.
      Column {
        id: olympicsBlock
        readonly property var olympicLeagues: root.service ? root.service.olympicLeagues : []
        readonly property var countryOptions: {
          var seen = {}
          var out = []
          for (var i = 0; i < olympicLeagues.length; i++) {
            var teams = (root.service && root.service.teamsByLeague[olympicLeagues[i]]) || []
            for (var j = 0; j < teams.length; j++) {
              if (seen[teams[j].abbr]) continue
              seen[teams[j].abbr] = true
              out.push({ value: teams[j].abbr, label: teams[j].name })
            }
          }
          out.sort(function(a, b) { return a.label.localeCompare(b.label) })
          return out
        }

        width: column.width
        spacing: Style.space(6)

        PanelSectionHeader {
          text: Strings.t(root.language, "sportGroup_olympics")
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          textFormat: Text.PlainText
          width: olympicsBlock.width
          text: Strings.t(root.language, "olympicsHelp")
          color: Qt.darker(root.foreground, 1.5)
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Row {
          width: olympicsBlock.width
          spacing: Style.space(8)

          TextField {
            id: olympicSlugField
            width: Math.max(Style.space(60), olympicsBlock.width - olympicAddButton.width - parent.spacing)
            placeholderText: Strings.t(root.language, "olympicEventPlaceholder")
            foreground: root.foreground
          }

          Button {
            id: olympicAddButton
            text: Strings.t(root.language, "addLeague")
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              if (root.service && olympicSlugField.text.trim() !== "") {
                root.service.addOlympicLeague(olympicSlugField.text.trim())
                olympicSlugField.text = ""
              }
            }
          }
        }

        Repeater {
          model: olympicsBlock.olympicLeagues
          delegate: Row {
            id: olympicLeagueRow
            required property string modelData
            width: olympicsBlock.width
            spacing: Style.space(8)

            Component.onCompleted: if (root.service) root.service.ensureTeams(olympicLeagueRow.modelData)

            Text {
              textFormat: Text.PlainText
              text: Sports.leagueLabel(olympicLeagueRow.modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              text: "· " + Strings.t(root.language, "removeLeague")
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.removeLeague(olympicLeagueRow.modelData)
              }
            }
          }
        }

        LeaguePicker {
          width: olympicsBlock.width
          visible: olympicsBlock.olympicLeagues.length > 0
          showLabel: false
          options: olympicsBlock.countryOptions
          values: root.service ? root.service.followedCountries : []
          foreground: root.foreground
          fontFamily: root.fontFamily
          placeholderText: Strings.t(root.language, "searchPlaceholder")
          emptyText: Strings.t(root.language, "noOptions")
          noSelectionText: Strings.t(root.language, "followedCountries")
          selectedSuffix: Strings.t(root.language, "selectedSuffix")
          onChanged: function(vals) { if (root.service) root.service.setFollowedCountries(vals) }
        }
      }
    }
  }
}
