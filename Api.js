.pragma library

// ESPN's unofficial JSON API. No API key. Not documented/versioned by
// ESPN, so parsing here is defensive on purpose — a shape change should
// degrade to an empty list, never crash the service.

var BASE_SITE = "https://site.api.espn.com/apis/site/v2/sports/"
var BASE_CORE = "https://site.api.espn.com/apis/v2/sports/"

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
    id: String(event.id || competition.id || ""),
    leagueSlug: leagueSlug,
    startDate: String(event.date || competition.date || ""),
    state: String(statusType.state || "pre"), // "pre" | "in" | "post"
    completed: statusType.completed === true,
    statusDetail: String(statusType.shortDetail || statusType.detail || statusType.description || ""),
    homeTeamId: String(homeTeam.id || ""),
    homeTeamName: String(homeTeam.shortDisplayName || homeTeam.displayName || homeTeam.name || ""),
    homeTeamAbbr: String(homeTeam.abbreviation || ""),
    homeScore: home.score !== undefined && home.score !== null ? String(home.score) : "",
    awayTeamId: String(awayTeam.id || ""),
    awayTeamName: String(awayTeam.shortDisplayName || awayTeam.displayName || awayTeam.name || ""),
    awayTeamAbbr: String(awayTeam.abbreviation || ""),
    awayScore: away.score !== undefined && away.score !== null ? String(away.score) : "",
    lastPlay: String((situation.lastPlay && situation.lastPlay.text) || situation.downDistanceText || "")
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
  for (var i = 0; i < competitors.length; i++) {
    var c = competitors[i]
    var athlete = c.athlete || {}
    var record = (c.records && c.records[0] && c.records[0].summary) ? String(c.records[0].summary) : ""
    rows.push({
      id: String(c.id || i),
      name: String(athlete.shortName || athlete.displayName || athlete.fullName || ""),
      score: c.score !== undefined && c.score !== null ? String(c.score) : "",
      winner: c.winner === true,
      record: record
    })
  }

  return {
    kind: "leaderboard",
    id: String(event.id || competition.id || ""),
    leagueSlug: leagueSlug,
    name: String(event.shortName || event.name || ""),
    startDate: String(event.date || competition.date || ""),
    state: String(statusType.state || "pre"),
    completed: statusType.completed === true,
    statusDetail: String(statusType.shortDetail || statusType.detail || statusType.description || ""),
    rows: rows
  }
}

function parseScoreboard(raw, leagueSlug, kind) {
  var parsed = safeParse(raw)
  if (!parsed || !parsed.events) return []
  var out = []
  for (var i = 0; i < parsed.events.length; i++) {
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
  for (var i = 0; i < sports.length; i++) {
    var leagues = sports[i].leagues || []
    for (var j = 0; j < leagues.length; j++) {
      var teams = leagues[j].teams || []
      for (var k = 0; k < teams.length; k++) {
        var t = teams[k].team || {}
        if (!t.id) continue
        out.push({
          id: String(t.id),
          name: String(t.shortDisplayName || t.displayName || t.name || ""),
          abbr: String(t.abbreviation || "")
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
  for (var i = 0; i < groups.length; i++) {
    var group = groups[i]
    var entries = (group.standings && group.standings.entries) || []
    var rows = []
    for (var j = 0; j < entries.length; j++) {
      var entry = entries[j]
      var team = entry.team || entry.athlete || {}
      var stats = entry.stats || []
      var byName = ({})
      for (var s = 0; s < stats.length; s++) byName[stats[s].name] = stats[s]

      var points = byName.points ? byName.points.displayValue
        : (byName.championshipPts ? byName.championshipPts.displayValue
        : (byName.winPercent ? byName.winPercent.displayValue : ""))

      rows.push({
        teamId: String(team.id || ""),
        teamName: String(team.shortDisplayName || team.displayName || team.fullName || team.name || ""),
        wins: byName.wins ? String(byName.wins.displayValue) : "-",
        losses: byName.losses ? String(byName.losses.displayValue) : "-",
        ties: byName.ties ? String(byName.ties.displayValue) : "",
        points: String(points || ""),
        rank: byName.rank ? String(byName.rank.displayValue) : String(j + 1)
      })
    }
    out.push({ groupName: String(group.name || ""), rows: rows })
  }
  return out
}
