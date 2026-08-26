.pragma library

// ESPN's unofficial JSON API. No API key. Not documented/versioned by
// ESPN, so parsing here is defensive on purpose — a shape change should
// degrade to an empty list, never crash the service.

var BASE_SITE = "https://site.api.espn.com/apis/site/v2/sports/"
var BASE_CORE = "https://site.api.espn.com/apis/v2/sports/"

// Defensive ceilings on untrusted ESPN payloads — independent of the
// byte-size cap enforced in Service.qml before this file ever sees the
// body, in case a payload is small but pathological (a huge array of tiny
// objects, or one absurdly long string field).
var MAX_EVENTS = 500          // scoreboard events / leaderboard rows per league per fetch
var MAX_TEAMS = 500           // teams endpoint
var MAX_GROUPS = 50           // standings conference/division groups
var MAX_ROWS_PER_GROUP = 100  // standings rows per group
var MAX_STR_LEN = 300         // names, status text, ids, etc.
var MAX_URL_LEN = 500         // logo URLs

function capStr(value, maxLen) {
  var s = String(value || "")
  return s.length > maxLen ? s.slice(0, maxLen) : s
}

function scoreboardUrl(slug, dateStr) {
  var url = BASE_SITE + slug + "/scoreboard"
  if (dateStr) url += "?dates=" + dateStr
  return url
}

function teamsUrl(slug) {
  return BASE_SITE + slug + "/teams?limit=200"
}

function standingsUrl(slug) {
  return BASE_CORE + slug + "/standings"
}

function safeParse(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (parsed && typeof parsed === "object") return parsed
  } catch (e) {
    // Malformed/empty response (timeout, ESPN hiccup, invalid slug) — treat
    // as "nothing to show" rather than propagating the error.
  }
  return null
}

function competitorFor(competition, side) {
  var comps = (competition && competition.competitors) || []
  for (var i = 0; i < comps.length; i++) {
    if (comps[i].homeAway === side) return comps[i]
  }
  return null
}

// Head-to-head sports: soccer, hockey, basketball, football, baseball.
function parseMatch(event, leagueSlug) {
  if (!event) return null
  var competition = (event.competitions && event.competitions[0]) || null
  if (!competition) return null
  var statusType = (competition.status && competition.status.type)
    || (event.status && event.status.type) || {}
  var home = competitorFor(competition, "home")
  var away = competitorFor(competition, "away")
  if (!home || !away) return null

  var situation = competition.situation || {}
  var homeTeam = home.team || {}
  var awayTeam = away.team || {}

  return {
    kind: "match",
    id: capStr(event.id || competition.id || "", MAX_STR_LEN),
    leagueSlug: leagueSlug,
    startDate: capStr(event.date || competition.date || "", MAX_STR_LEN),
    state: String(statusType.state || "pre"), // "pre" | "in" | "post"
    completed: statusType.completed === true,
    statusDetail: capStr(statusType.shortDetail || statusType.detail || statusType.description || "", MAX_STR_LEN),
    homeTeamId: capStr(homeTeam.id || "", MAX_STR_LEN),
    homeTeamName: capStr(homeTeam.shortDisplayName || homeTeam.displayName || homeTeam.name || "", MAX_STR_LEN),
    homeTeamAbbr: capStr(homeTeam.abbreviation || "", MAX_STR_LEN),
    homeTeamLogo: capStr((homeTeam.logos && homeTeam.logos[0] && homeTeam.logos[0].href) || homeTeam.logo || "", MAX_URL_LEN),
    homeScore: home.score !== undefined && home.score !== null ? capStr(home.score, MAX_STR_LEN) : "",
    awayTeamId: capStr(awayTeam.id || "", MAX_STR_LEN),
    awayTeamName: capStr(awayTeam.shortDisplayName || awayTeam.displayName || awayTeam.name || "", MAX_STR_LEN),
    awayTeamAbbr: capStr(awayTeam.abbreviation || "", MAX_STR_LEN),
    awayTeamLogo: capStr((awayTeam.logos && awayTeam.logos[0] && awayTeam.logos[0].href) || awayTeam.logo || "", MAX_URL_LEN),
    awayScore: away.score !== undefined && away.score !== null ? capStr(away.score, MAX_STR_LEN) : "",
    lastPlay: capStr((situation.lastPlay && situation.lastPlay.text) || situation.downDistanceText || "", MAX_STR_LEN)
  }
}

// Individual-competitor sports: golf, motorsport, combat. ESPN lists
// competitors without homeAway — each has an `athlete` and either a `score`
// (golf, under/over par) or a `winner` flag + fight/season record.
function parseLeaderboardEvent(event, leagueSlug) {
  if (!event) return null
  var competition = (event.competitions && event.competitions[0]) || null
  if (!competition) return null
  var statusType = (competition.status && competition.status.type)
    || (event.status && event.status.type) || {}
  var competitors = competition.competitors || []
  var rows = []
  for (var i = 0; i < competitors.length && rows.length < MAX_EVENTS; i++) {
    var c = competitors[i]
    var athlete = c.athlete || {}
    var record = (c.records && c.records[0] && c.records[0].summary) ? capStr(c.records[0].summary, MAX_STR_LEN) : ""
    rows.push({
      id: capStr(c.id || i, MAX_STR_LEN),
      name: capStr(athlete.shortName || athlete.displayName || athlete.fullName || "", MAX_STR_LEN),
      score: c.score !== undefined && c.score !== null ? capStr(c.score, MAX_STR_LEN) : "",
      winner: c.winner === true,
      record: record
    })
  }

  return {
    kind: "leaderboard",
    id: capStr(event.id || competition.id || "", MAX_STR_LEN),
    leagueSlug: leagueSlug,
    name: capStr(event.shortName || event.name || "", MAX_STR_LEN),
    startDate: capStr(event.date || competition.date || "", MAX_STR_LEN),
    state: String(statusType.state || "pre"),
    completed: statusType.completed === true,
    statusDetail: capStr(statusType.shortDetail || statusType.detail || statusType.description || "", MAX_STR_LEN),
    rows: rows
  }
}

function parseScoreboard(raw, leagueSlug, kind) {
  var parsed = safeParse(raw)
  if (!parsed || !parsed.events) return []
  var out = []
  for (var i = 0; i < parsed.events.length && out.length < MAX_EVENTS; i++) {
    var item = kind === "leaderboard"
      ? parseLeaderboardEvent(parsed.events[i], leagueSlug)
      : parseMatch(parsed.events[i], leagueSlug)
    if (item) out.push(item)
  }
  return out
}

function parseTeams(raw) {
  var parsed = safeParse(raw)
  if (!parsed) return []
  var out = []
  var sports = parsed.sports || []
  for (var i = 0; i < sports.length && out.length < MAX_TEAMS; i++) {
    var leagues = sports[i].leagues || []
    for (var j = 0; j < leagues.length && out.length < MAX_TEAMS; j++) {
      var teams = leagues[j].teams || []
      for (var k = 0; k < teams.length && out.length < MAX_TEAMS; k++) {
        var t = teams[k].team || {}
        if (!t.id) continue
        out.push({
          id: capStr(t.id, MAX_STR_LEN),
          name: capStr(t.shortDisplayName || t.displayName || t.name || "", MAX_STR_LEN),
          abbr: capStr(t.abbreviation || "", MAX_STR_LEN)
        })
      }
    }
  }
  out.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return out
}

// Standings responses come back either as `{ children: [{ name, standings }] }`
// (conferences/divisions, or per-race "Driver Standings" for motorsport) or
// a flat `{ standings }` for single-table leagues. Entries carry `team` for
// team sports and `athlete` for individual ones (motorsport driver
// standings) — both are normalized into `teamName` here.
function parseStandings(raw) {
  var parsed = safeParse(raw)
  if (!parsed) return []
  var groups = parsed.children && parsed.children.length
    ? parsed.children
    : (parsed.standings ? [{ name: "", standings: parsed.standings }] : [])

  var out = []
  for (var i = 0; i < groups.length && out.length < MAX_GROUPS; i++) {
    var group = groups[i]
    var entries = (group.standings && group.standings.entries) || []
    var rows = []
    for (var j = 0; j < entries.length && rows.length < MAX_ROWS_PER_GROUP; j++) {
      var entry = entries[j]
      var team = entry.team || entry.athlete || {}
      var stats = entry.stats || []
      var byName = ({})
      for (var s = 0; s < stats.length; s++) byName[stats[s].name] = stats[s]

      var points = byName.points ? byName.points.displayValue
        : (byName.championshipPts ? byName.championshipPts.displayValue
        : (byName.winPercent ? byName.winPercent.displayValue : ""))

      rows.push({
        teamId: capStr(team.id || "", MAX_STR_LEN),
        teamName: capStr(team.shortDisplayName || team.displayName || team.fullName || team.name || "", MAX_STR_LEN),
        wins: byName.wins ? capStr(byName.wins.displayValue, MAX_STR_LEN) : "-",
        losses: byName.losses ? capStr(byName.losses.displayValue, MAX_STR_LEN) : "-",
        ties: byName.ties ? capStr(byName.ties.displayValue, MAX_STR_LEN) : "",
        points: capStr(points || "", MAX_STR_LEN),
        rank: byName.rank ? capStr(byName.rank.displayValue, MAX_STR_LEN) : String(j + 1)
      })
    }
    out.push({ groupName: capStr(group.name || "", MAX_STR_LEN), rows: rows })
  }
  return out
}
