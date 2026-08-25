import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../" // Picker
import "../Sports.js" as Sports
import "../Strings.js" as Strings

// Tab 2: standings for one followed league at a time, picked from a
// dropdown scoped to the leagues the user actually follows.
Item {
  id: root

  property var service: null
  property string language: "en"
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property var followedLeagues: service ? service.followedLeagues : []
  readonly property var leagueOptions: {
    var out = []
    for (var i = 0; i < followedLeagues.length; i++)
      out.push({ value: followedLeagues[i], label: Sports.leagueLabel(followedLeagues[i]) })
    return out
  }

  property string selectedLeague: ""

  onLeagueOptionsChanged: {
    if (followedLeagues.indexOf(selectedLeague) === -1)
      selectedLeague = leagueOptions.length > 0 ? leagueOptions[0].value : ""
  }

  onSelectedLeagueChanged: if (service && selectedLeague !== "") service.ensureStandings(selectedLeague)

  readonly property var groups: (service && selectedLeague !== "") ? (service.standingsByLeague[selectedLeague] || []) : []

  Column {
    anchors.fill: parent
    spacing: Style.space(12)

    Picker {
      id: leaguePicker
      width: parent.width
      visible: root.leagueOptions.length > 0
      label: Strings.t(root.language, "selectLeague")
      options: root.leagueOptions
      value: root.selectedLeague
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(v) { root.selectedLeague = v }
    }

    Text {
      visible: root.leagueOptions.length === 0
      width: parent.width
      text: Strings.t(root.language, "noFollowed")
      color: Qt.darker(root.foreground, 1.5)
      wrapMode: Text.WordWrap
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Flickable {
      width: parent.width
      height: Math.max(0, parent.height - (leaguePicker.visible ? leaguePicker.height + Style.space(12) : 0))
      contentWidth: width
      contentHeight: standingsColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: standingsColumn
        width: parent.width
        spacing: Style.space(10)

        Text {
          visible: root.selectedLeague !== "" && root.groups.length === 0
          width: parent.width
          text: Strings.t(root.language, "noStandings")
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Repeater {
          model: root.groups
          delegate: Column {
            required property var modelData
            width: standingsColumn.width
            spacing: Style.space(4)

            PanelSectionHeader {
              visible: modelData.groupName !== ""
              text: modelData.groupName
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: modelData.rows
              delegate: RowLayout {
                id: standingsRow
                required property var modelData
                width: standingsColumn.width
                spacing: Style.space(8)

                Text {
                  text: standingsRow.modelData.rank
                  color: Qt.darker(root.foreground, 1.3)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  Layout.preferredWidth: Style.space(22)
                }
                Text {
                  Layout.fillWidth: true
                  text: standingsRow.modelData.teamName
                  color: root.foreground
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  text: standingsRow.modelData.wins + "-" + standingsRow.modelData.losses
                    + (standingsRow.modelData.ties !== "" ? "-" + standingsRow.modelData.ties : "")
                  color: Qt.darker(root.foreground, 1.2)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  Layout.preferredWidth: Style.space(64)
                }
                Text {
                  text: standingsRow.modelData.points
                  color: root.foreground
                  font.bold: true
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  Layout.preferredWidth: Style.space(34)
                  horizontalAlignment: Text.AlignRight
                }
              }
            }
          }
        }
      }
    }
  }
}
