import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Strings.js" as Strings

// Panel-header widget shown instead of the static trophy icon when the
// "heroWidget" setting is "scoreboard": a compact score/countdown pill you
// can click to expand into a fuller match card. Falls back to the same
// trophy glyph the default hero uses whenever there's nothing followed to
// show, so turning this setting on never leaves a blank header.
Item {
  id: root

  property var service: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property string language: "en"

  readonly property var liveMatch: service && service.allLiveFollowedMatches.length > 0
    ? service.allLiveFollowedMatches[0] : null
  // Today-only by design: liveMatchesByLeague only ever holds today's
  // scoreboard, so this needs no extra ESPN call for a multi-day lookahead.
  readonly property var nextMatch: !liveMatch && service ? service.nextFollowedMatchToday() : null
  readonly property bool hasContent: liveMatch !== null || nextMatch !== null

  property bool expanded: false

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Timer {
    // Countdown granularity is minutes, so a slow re-render tick is plenty
    // — no need for a per-second timer here.
    interval: 30000
    running: root.nextMatch !== null
    repeat: true
    onTriggered: root._tick = !root._tick
  }
  property bool _tick: false

  function countdownText() {
    var _dep = root._tick // read so this function re-evaluates when the tick flips
    if (!root.nextMatch) return ""
    var diffMs = new Date(root.nextMatch.startDate).getTime() - Date.now()
    if (diffMs <= 0) return Strings.t(root.language, "heroKickoffSoon")
    var mins = Math.max(1, Math.round(diffMs / 60000))
    var h = Math.floor(mins / 60)
    var m = mins % 60
    var duration = h > 0 ? (h + "h" + (m < 10 ? "0" : "") + m) : (m + "min")
    return Strings.t(root.language, "heroKickoffIn").replace("%1", duration)
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.hasContent
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.expanded = !root.expanded
  }

  Column {
    id: content
    spacing: Style.space(2)

    Text {
      visible: !root.hasContent
      text: Model.GLYPH_TROPHY
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
    }

    RowLayout {
      visible: root.hasContent && !root.expanded
      spacing: Style.space(6)

      Text {
        text: root.liveMatch ? Model.glyphForSlug(root.liveMatch.leagueSlug) : Model.GLYPH_TROPHY
        color: root.liveMatch ? Color.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
      }

      Text {
        text: root.liveMatch ? Model.matchLabel(root.liveMatch) : root.countdownText()
        color: root.foreground
        font.bold: true
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Column {
      visible: root.hasContent && root.expanded
      spacing: Style.space(4)

      Text {
        width: Style.space(220)
        wrapMode: Text.WordWrap
        text: root.liveMatch
          ? (root.liveMatch.awayTeamName + "  " + root.liveMatch.awayScore + " - " + root.liveMatch.homeScore + "  " + root.liveMatch.homeTeamName)
          : (root.nextMatch.awayTeamName + " " + Strings.t(root.language, "heroVs") + " " + root.nextMatch.homeTeamName)
        color: root.foreground
        font.bold: true
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        text: root.liveMatch ? root.liveMatch.statusDetail : root.countdownText()
        color: Qt.darker(root.foreground, 1.3)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
