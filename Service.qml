import QtQuick
import Quickshell
import Quickshell.Io
import "Api.js" as Api
import "Model.js" as Model
import "Sports.js" as Sports
import "Strings.js" as Strings

// Headless singleton behind the plugin. A bar widget is instantiated once
// per monitor, so all polling, state and notification logic lives here —
// the shell mounts exactly one service, and a two-monitor setup should not
// double the ESPN traffic or double-fire notifications.
Item {
  id: root

  // Injected by the bar widget (the shell does not inject settings into
  // services directly — see BarWidget.qml's syncService()).
  property var shell: null
  property var settings: ({})

  // ---------------------------------------------------------------- settings

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 20, 10, 120)
  readonly property int liveRefreshIntervalSec: intSetting("liveRefreshIntervalSec", 5, 3, 30)
  readonly property int scheduleRefreshIntervalMin: intSetting("scheduleRefreshIntervalMin", 5, 1, 60)
  readonly property bool compactBarLabel: setting("compactBarLabel", true) === true
  readonly property string language: String(setting("language", "en"))
  readonly property string footballName: String(setting("footballName", "soccer"))
  readonly property string heroWidget: String(setting("heroWidget", "trophy"))

  // ---------------------------------------------------------------- persisted state
  //
  // Followed leagues/teams and notification preferences are too dynamic
  // (arbitrary-length lists, nested objects) for the bar-widget settings
  // schema, so they live in their own file next to the plugin, following
  // the FileView pattern used elsewhere in Omarchy for plugin-owned state.

  property var followedLeagues: []
  property var followedTeams: []      // [{ league, id, name }]
  // Subset of followedLeagues the user has explicitly added as an Olympic
  // event (see addOlympicLeague) — ESPN has no dedicated Olympics sport
  // bucket, so there's no way to detect this from the slug alone.
  property var olympicLeagues: []
  property var followedCountries: []  // country abbreviations, Olympic leagues only (e.g. ["FRA","CAN"])
  property var notifications: ({
    enabled: true,
    goals: true,
    important: true,
    scoreChange: false,
    matchStatus: true,
    scope: "teams"   // "teams" | "leagues"
  })
  property var lastSeenMatches: ({})  // matchId -> { state, homeScore, awayScore, lastPlay }
  property bool stateLoaded: false

  function teamIdsForLeague(slug) {
    var out = []
    for (var i = 0; i < followedTeams.length; i++) if (followedTeams[i].league === slug) out.push(followedTeams[i].id)
    return out
  }

  function setFollowedCountries(abbrs) {
    followedCountries = abbrs
    saveDebounce.restart()
  }

  function isOlympicLeague(slug) {
    return olympicLeagues.indexOf(slug) !== -1
  }

  // Adds a user-supplied ESPN slug as an Olympic event: ESPN publishes
  // these under their normal sport (e.g. "basketball/mens-olympics-
  // basketball"), only while that edition's Games are on, with no
  // consistent naming to hardcode a catalogue from — so unlike other
  // sports, Olympics has no curated league list, just this.
  function addOlympicLeague(slug) {
    var clean = String(slug || "").trim()
    if (clean === "") return
    if (followedLeagues.indexOf(clean) === -1) followedLeagues = followedLeagues.concat([clean])
    if (olympicLeagues.indexOf(clean) === -1) olympicLeagues = olympicLeagues.concat([clean])
    refreshScoreboards()
    saveDebounce.restart()
  }

  // Olympic "teams" are national teams: following a country is a single
  // cross-sport filter (works across every Olympic league followed at
  // once), unlike ordinary leagues where team ids only make sense
  // per-league. Empty selection = every event, i.e. general tracking.
  function isEventFollowed(match, slug) {
    if (isOlympicLeague(slug)) return Model.matchIsFollowedByCountry(match, followedCountries)
    return Model.matchIsFollowed(match, teamIdsForLeague(slug))
  }

  function setLeaguesForSport(sportId, slugsForThatSport) {
    var next = []
    for (var i = 0; i < followedLeagues.length; i++) {
      if (Model.sportIdFromSlug(followedLeagues[i]) !== sportId) next.push(followedLeagues[i])
    }
    for (var j = 0; j < slugsForThatSport.length; j++) next.push(slugsForThatSport[j])
    followedLeagues = next
    _pruneTeamsToFollowedLeagues()
    refreshScoreboards()
    saveDebounce.restart()
  }

  function addCustomLeague(slug) {
    var clean = String(slug || "").trim()
    if (clean === "" || followedLeagues.indexOf(clean) !== -1) return
    followedLeagues = followedLeagues.concat([clean])
    refreshScoreboards()
    saveDebounce.restart()
  }

  function removeLeague(slug) {
    var next = []
    for (var i = 0; i < followedLeagues.length; i++) if (followedLeagues[i] !== slug) next.push(followedLeagues[i])
    followedLeagues = next
    if (olympicLeagues.indexOf(slug) !== -1) {
      var nextOlympic = []
      for (var j = 0; j < olympicLeagues.length; j++) if (olympicLeagues[j] !== slug) nextOlympic.push(olympicLeagues[j])
      olympicLeagues = nextOlympic
    }
    _pruneTeamsToFollowedLeagues()
    saveDebounce.restart()
  }

  function setTeamsForLeague(slug, teamIds) {
    var next = []
    for (var i = 0; i < followedTeams.length; i++) if (followedTeams[i].league !== slug) next.push(followedTeams[i])
    var teams = teamsByLeague[slug] || []
    for (var j = 0; j < teamIds.length; j++) {
      var id = teamIds[j]
      var name = id
      for (var k = 0; k < teams.length; k++) if (teams[k].id === id) { name = teams[k].name; break }
      next.push({ league: slug, id: id, name: name })
    }
    followedTeams = next
    saveDebounce.restart()
  }

  function _pruneTeamsToFollowedLeagues() {
    var next = []
    for (var i = 0; i < followedTeams.length; i++)
      if (followedLeagues.indexOf(followedTeams[i].league) !== -1) next.push(followedTeams[i])
    followedTeams = next
  }

  function setNotifPref(key, value) {
    var next = {}
    for (var k in notifications) next[k] = notifications[k]
    next[key] = value
    notifications = next
    saveDebounce.restart()
  }

  function _serialize() {
    return JSON.stringify({
      followedLeagues: followedLeagues,
      followedTeams: followedTeams,
      olympicLeagues: olympicLeagues,
      followedCountries: followedCountries,
      notifications: notifications,
      lastSeenMatches: lastSeenMatches
    }, null, 2)
  }

  function _applyState(raw) {
    var text = String(raw || "").trim()
    var parsed = null
    if (text !== "") {
      try { parsed = JSON.parse(text) } catch (e) { parsed = null }
    }
    if (parsed && typeof parsed === "object") {
      followedLeagues = Array.isArray(parsed.followedLeagues) ? parsed.followedLeagues : []
      followedTeams = Array.isArray(parsed.followedTeams) ? parsed.followedTeams : []
      olympicLeagues = Array.isArray(parsed.olympicLeagues) ? parsed.olympicLeagues : []
      followedCountries = Array.isArray(parsed.followedCountries) ? parsed.followedCountries : []
      if (parsed.notifications && typeof parsed.notifications === "object") {
        var merged = {}
        for (var k in notifications) merged[k] = notifications[k]
        for (var k2 in parsed.notifications) merged[k2] = parsed.notifications[k2]
        notifications = merged
      }
      lastSeenMatches = (parsed.lastSeenMatches && typeof parsed.lastSeenMatches === "object") ? parsed.lastSeenMatches : {}
    }
    stateLoaded = true
    refreshScoreboards()
    refreshStandingsForFollowed()
  }

  Timer {
    id: saveDebounce
    interval: 500
    repeat: false
    onTriggered: if (root.stateLoaded) stateFile.setText(root._serialize())
  }

  readonly property string statePath: Qt.resolvedUrl("data/state.json").toString().replace(/^file:\/\//, "")

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root._applyState(text())
    onLoadFailed: root._applyState("")
    onFileChanged: reload()
  }

  // ---------------------------------------------------------------- live data

  property var liveMatchesByLeague: ({})   // slug -> [match]
  property var standingsByLeague: ({})     // slug -> [{ groupName, rows }]
  property var teamsByLeague: ({})         // slug -> [{ id, name, abbr }]

  readonly property var allLiveFollowedMatches: {
    var out = []
    for (var i = 0; i < followedLeagues.length; i++) {
      var slug = followedLeagues[i]
      var matches = liveMatchesByLeague[slug] || []
      for (var j = 0; j < matches.length; j++) {
        if (Model.isLive(matches[j]) && isEventFollowed(matches[j], slug)) out.push(matches[j])
      }
    }
    return out
  }

  // Earliest not-yet-started followed match still to come today, or null.
  // Scoped to today on purpose: `liveMatchesByLeague` only ever holds
  // today's scoreboard (see refreshScoreboards()), so this is free — no
  // extra ESPN call for a multi-day lookahead.
  function nextFollowedMatchToday() {
    var best = null
    for (var i = 0; i < followedLeagues.length; i++) {
      var slug = followedLeagues[i]
      var matches = liveMatchesByLeague[slug] || []
      for (var j = 0; j < matches.length; j++) {
        var m = matches[j]
        if (!Model.isUpcoming(m) || m.kind === "leaderboard" || !isEventFollowed(m, slug)) continue
        if (!best || new Date(m.startDate).getTime() < new Date(best.startDate).getTime()) best = m
      }
    }
    return best
  }

  function ensureTeams(slug) {
    if (teamsByLeague[slug] !== undefined) return
    var next = {}
    for (var k in teamsByLeague) next[k] = teamsByLeague[k]
    next[slug] = []
    teamsByLeague = next
    _teamsQueue.push(slug)
    _pumpTeamsQueue()
  }

  function ensureStandings(slug) {
    if (!slug) return
    _standingsQueue = [slug]
    _pumpStandingsQueue()
  }

  function refreshStandingsForFollowed() {
    _standingsQueue = followedLeagues.slice()
    _pumpStandingsQueue()
  }

  // -------------------------------------------------------- scoreboard polling
  //
  // One short-lived curl Process per followed league, fired in parallel on
  // every refresh (followed-league counts are small in practice), instead
  // of the old shared single-Process sequential queue. That queue added a
  // "wait your turn" delay on top of the poll interval for any league past
  // the first — this removes it, which matters for how fast a goal
  // notification actually lands.

  function refreshScoreboards() {
    if (followedLeagues.length === 0) { liveMatchesByLeague = {}; return }
    for (var i = 0; i < followedLeagues.length; i++) _fetchScoreboard(followedLeagues[i])
  }

  function _fetchScoreboard(slug) {
    var worker = scoreboardWorkerComponent.createObject(root, { slug: slug })
    if (worker) worker.start()
  }

  function _applyScoreboard(slug, raw) {
    var matches = Api.parseScoreboard(raw, slug, Sports.leagueKind(slug))
    var next = {}
    for (var k in liveMatchesByLeague) next[k] = liveMatchesByLeague[k]
    next[slug] = matches
    liveMatchesByLeague = next
    _detectEvents(slug, matches)
  }

  Component {
    id: scoreboardWorkerComponent
    Process {
      id: scoreboardWorker
      property string slug: ""
      command: []
      stdout: StdioCollector { id: scoreboardOut; waitForEnd: true }
      function start() {
        scoreboardWorker.command = ["curl", "-s", "--max-time", "8", Api.scoreboardUrl(scoreboardWorker.slug, Model.todayStamp())]
        scoreboardWorker.running = true
      }
      onExited: function(exitCode) {
        if (exitCode === 0) root._applyScoreboard(scoreboardWorker.slug, scoreboardOut.text)
        scoreboardWorker.destroy()
      }
    }
  }

  // -------------------------------------------------------- standings polling

  property var _standingsQueue: []
  property bool _standingsBusy: false

  function _pumpStandingsQueue() {
    if (_standingsBusy || _standingsQueue.length === 0) return
    var slug = _standingsQueue.shift()
    _standingsBusy = true
    standingsProcess.currentSlug = slug
    standingsProcess.command = ["curl", "-s", "--max-time", "8", Api.standingsUrl(slug)]
    standingsProcess.running = true
  }

  Process {
    id: standingsProcess
    property string currentSlug: ""
    running: false
    command: []
    stdout: StdioCollector { id: standingsOut; waitForEnd: true }
    onExited: function(exitCode) {
      root._standingsBusy = false
      if (exitCode === 0) {
        var groups = Api.parseStandings(standingsOut.text)
        var next = {}
        for (var k in root.standingsByLeague) next[k] = root.standingsByLeague[k]
        next[standingsProcess.currentSlug] = groups
        root.standingsByLeague = next
      }
      root._pumpStandingsQueue()
    }
  }

  // ------------------------------------------------------------- teams fetch

  property var _teamsQueue: []
  property bool _teamsBusy: false

  function _pumpTeamsQueue() {
    if (_teamsBusy || _teamsQueue.length === 0) return
    var slug = _teamsQueue.shift()
    _teamsBusy = true
    teamsProcess.currentSlug = slug
    teamsProcess.command = ["curl", "-s", "--max-time", "8", Api.teamsUrl(slug)]
    teamsProcess.running = true
  }

  Process {
    id: teamsProcess
    property string currentSlug: ""
    running: false
    command: []
    stdout: StdioCollector { id: teamsOut; waitForEnd: true }
    onExited: function(exitCode) {
      root._teamsBusy = false
      if (exitCode === 0) {
        var teams = Api.parseTeams(teamsOut.text)
        var next = {}
        for (var k in root.teamsByLeague) next[k] = root.teamsByLeague[k]
        next[teamsProcess.currentSlug] = teams
        root.teamsByLeague = next
      }
      root._pumpTeamsQueue()
    }
  }

  // ------------------------------------------------------------- notifications

  function _detectEvents(slug, matches) {
    var notifyAtAll = notifications.enabled === true
    var nextSeen = {}
    for (var k in lastSeenMatches) nextSeen[k] = lastSeenMatches[k]
    var sportGlyph = Model.glyphForSlug(slug)

    for (var i = 0; i < matches.length; i++) {
      var m = matches[i]
      var prev = lastSeenMatches[m.id]
      var relevant = notifications.scope === "leagues" ? true : isEventFollowed(m, slug)
      var label = Model.eventLabel(m)

      if (notifyAtAll && relevant && prev) {
        if (notifications.matchStatus && prev.state !== m.state) {
          if (m.state === "in") _notify(label, Model.GLYPH_WHISTLE, m.statusDetail)
          else if (m.state === "post") _notify(label, Model.GLYPH_TROPHY, Strings.t(root.language, "finished"))
        } else if (m.kind !== "leaderboard" && m.state === "in" && (notifications.goals || notifications.scoreChange)
                   && (prev.homeScore !== m.homeScore || prev.awayScore !== m.awayScore)) {
          _notify(label, sportGlyph, m.statusDetail)
        }
        if (m.kind !== "leaderboard" && notifications.important && m.state === "in"
            && m.lastPlay !== "" && m.lastPlay !== prev.lastPlay) {
          _notify(label, Model.GLYPH_ALERT, m.lastPlay)
        }
      }

      nextSeen[m.id] = m.kind === "leaderboard"
        ? { state: m.state, kind: m.kind }
        : { state: m.state, kind: m.kind, homeScore: m.homeScore, awayScore: m.awayScore, lastPlay: m.lastPlay }
    }

    lastSeenMatches = nextSeen
    saveDebounce.restart()
  }

  function _notify(title, glyph, body) {
    var safeTitle = String(title || "").replace(/'/g, "'\\''")
    var safeBody = String(body || "").replace(/'/g, "'\\''")
    var cmd = "if command -v omarchy-notification-send >/dev/null 2>&1; then "
      + "omarchy-notification-send '" + safeTitle + "' '" + safeBody + "' -g '" + glyph + "' -u normal --app-name 'Live Scores'; "
      + "else notify-send -u normal 'Live Scores: " + safeTitle + "' '" + safeBody + "'; fi"
    Quickshell.execDetached(["bash", "-c", cmd])
  }

  // ---------------------------------------------------------------- timers

  Timer {
    // Cheap-ish: one curl per followed league, only for leagues the user
    // actually follows. This is the "direct" tab's data source, and it
    // already includes today's not-yet-started matches, so it covers the
    // "upcoming" section too.
    //
    // Interval is adaptive: falls back to the slower, ESPN-friendly
    // refreshIntervalSec while nothing followed is live, but switches to
    // the short liveRefreshIntervalSec the moment a followed match is in
    // progress, so a goal shows up (and notifies) within a few seconds
    // instead of waiting out the idle interval.
    id: fastTimer
    interval: (root.allLiveFollowedMatches.length > 0 ? root.liveRefreshIntervalSec : root.refreshIntervalSec) * 1000
    repeat: true
    running: root.stateLoaded
    triggeredOnStart: true
    onTriggered: root.refreshScoreboards()
  }

  Timer {
    // Standings change rarely — a separate, slower schedule.
    id: slowTimer
    interval: root.scheduleRefreshIntervalMin * 60 * 1000
    repeat: true
    running: root.stateLoaded
    triggeredOnStart: false
    onTriggered: root.refreshStandingsForFollowed()
  }
}
