import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../Sports.js" as Sports
import "../Strings.js" as Strings

// Tab 1: live events + today's upcoming ones, grouped by followed league.
//
// Two shapes render here: head-to-head matches (soccer, hockey, basketball,
// football, baseball — two teams, a score) and leaderboard events (golf,
// motorsport, combat — a ranked list of individual athletes, no team to
// follow). A league with specific followed teams only shows those teams'
// matches; a league followed with no team picked shows everything.
Item {
  id: root

  property var service: null
  property string language: "en"
  property color foreground: Color.popups.text
  property string fontFamily: Style.font.family

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property var followedLeagues: service ? service.followedLeagues : []

  // Natural height of this tab's content, unclamped by the viewport —
  // Panel.qml reads this to size the tab area to whichever tab is active
  // instead of a fixed height that leaves empty space under short tabs.
  readonly property real contentHeight: column.implicitHeight

  // Delegates to the service's team/country filtering — Olympic leagues
  // filter by followed country across every Olympic sport at once,
  // ordinary leagues filter by followed team within that one league.
  function isFollowedFor(match, slug) {
    return service ? service.isEventFollowed(match, slug) : true
  }

  Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Style.space(14)

      Text {
        textFormat: Text.PlainText
        visible: root.followedLeagues.length === 0
        width: parent.width
        text: Strings.t(root.language, "noFollowed")
        color: root.dim
        wrapMode: Text.WordWrap
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Repeater {
        model: root.followedLeagues
        delegate: Column {
          id: leagueBlock
          required property string modelData
          width: column.width
          spacing: Style.space(6)

          readonly property var allEvents: root.service ? (root.service.liveMatchesByLeague[modelData] || []) : []
          readonly property bool leaderboard: Sports.leagueKind(modelData) === "leaderboard"
          readonly property var visibleMatches: allEvents.filter(function(m) { return root.isFollowedFor(m, leagueBlock.modelData) })
          readonly property var liveMatches: visibleMatches.filter(Model.isLive)
          readonly property var upcomingMatches: visibleMatches.filter(Model.isUpcoming)

          PanelSectionHeader {
            text: Sports.leagueLabel(leagueBlock.modelData)
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // -------------------------------------------------- head-to-head
          Repeater {
            model: leagueBlock.leaderboard ? [] : leagueBlock.liveMatches
            delegate: MatchRow {
              required property var modelData
              width: leagueBlock.width
              match: modelData
              foreground: root.foreground
              fontFamily: root.fontFamily
              language: root.language
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: !leagueBlock.leaderboard && leagueBlock.liveMatches.length === 0
            width: leagueBlock.width
            text: Strings.t(root.language, "noLiveMatches")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText
            visible: !leagueBlock.leaderboard && leagueBlock.upcomingMatches.length > 0
            width: leagueBlock.width
            text: Strings.t(root.language, "upcomingTitle")
            color: Qt.darker(root.foreground, 1.3)
            font.bold: true
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: leagueBlock.leaderboard ? [] : leagueBlock.upcomingMatches
            delegate: MatchRow {
              required property var modelData
              width: leagueBlock.width
              match: modelData
              foreground: root.foreground
              fontFamily: root.fontFamily
              language: root.language
            }
          }

          // ------------------------------------------------------ leaderboard
          Repeater {
            model: leagueBlock.leaderboard ? leagueBlock.allEvents : []
            delegate: LeaderboardEvent {
              required property var modelData
              width: leagueBlock.width
              event: modelData
              foreground: root.foreground
              fontFamily: root.fontFamily
              language: root.language
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: leagueBlock.leaderboard && leagueBlock.allEvents.length === 0
            width: leagueBlock.width
            text: Strings.t(root.language, "noLiveMatches")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  component MatchRow: Item {
    id: row
    property var match: null
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property string language: "en"

    readonly property bool live: Model.isLive(match)
    readonly property bool finished: Model.isFinished(match)

    implicitHeight: content.implicitHeight + Style.space(4)

    RowLayout {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: row.live ? "●" : (row.finished ? "" : Model.shortTime(row.match.startDate))
        color: row.live ? Color.urgent : Qt.darker(row.foreground, 1.4)
        font.pixelSize: Style.font.caption
        font.family: row.fontFamily
        Layout.preferredWidth: Style.space(36)
      }

      Image {
        source: row.match.awayTeamLogo || ""
        visible: source !== ""
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        Layout.preferredWidth: Style.space(18)
        Layout.preferredHeight: Style.space(18)
      }

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: row.match.awayTeamName
        color: row.foreground
        elide: Text.ElideRight
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        textFormat: Text.PlainText
        text: (row.finished || row.live) ? (row.match.awayScore + " - " + row.match.homeScore) : ""
        color: row.foreground
        font.bold: true
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        Layout.preferredWidth: Style.space(48)
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: row.match.homeTeamName
        color: row.foreground
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
      }

      Image {
        source: row.match.homeTeamLogo || ""
        visible: source !== ""
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        Layout.preferredWidth: Style.space(18)
        Layout.preferredHeight: Style.space(18)
      }

      Text {
        textFormat: Text.PlainText
        text: row.finished ? Strings.t(row.language, "finished") : (row.live ? row.match.statusDetail : "")
        color: Qt.darker(row.foreground, 1.4)
        font.pixelSize: Style.font.caption
        font.family: row.fontFamily
        Layout.preferredWidth: Style.space(70)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }
    }
  }

  // One tournament/race/fight card: its name + status, then its top rows
  // (golf leaderboard position, race classification, fight card).
  component LeaderboardEvent: Column {
    id: card
    property var event: null
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property string language: "en"

    readonly property bool live: Model.isLive(event)
    readonly property bool finished: Model.isFinished(event)
    readonly property var topRows: event && event.rows ? event.rows.slice(0, 5) : []

    spacing: Style.space(2)

    RowLayout {
      width: card.width
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: card.live ? "●" : ""
        color: Color.urgent
        font.pixelSize: Style.font.caption
        font.family: card.fontFamily
        Layout.preferredWidth: Style.space(14)
      }

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: card.event ? card.event.name : ""
        color: card.foreground
        font.bold: true
        elide: Text.ElideRight
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        textFormat: Text.PlainText
        text: card.finished ? Strings.t(card.language, "finished") : (card.event ? card.event.statusDetail : "")
        color: Qt.darker(card.foreground, 1.4)
        font.pixelSize: Style.font.caption
        font.family: card.fontFamily
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }
    }

    Repeater {
      model: card.topRows
      delegate: RowLayout {
        required property var modelData
        required property int index
        width: card.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: String(index + 1)
          color: Qt.darker(card.foreground, 1.3)
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
          Layout.preferredWidth: Style.space(16)
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: modelData.name
          color: modelData.winner ? card.foreground : Qt.darker(card.foreground, 1.1)
          font.bold: modelData.winner
          elide: Text.ElideRight
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          textFormat: Text.PlainText
          text: modelData.score !== "" ? modelData.score : modelData.record
          color: Qt.darker(card.foreground, 1.2)
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
