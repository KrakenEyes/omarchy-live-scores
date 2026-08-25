.pragma library

// Pure helpers shared by the service, the bar widget and the panel tabs, so
// none of them can drift on what a match state means or how it's grouped.
//
// Icons are single-color Nerd Font (Material Design Icons subset) glyphs,
// not emoji: emoji glyphs are full-color and ignore Text.color, so they
// can never follow the active Omarchy theme. These do, the same way every
// other glyph in the shell (chevrons, status icons, etc.) does.

var GLYPH_SOCCER = "󰒸"
var GLYPH_FOOTBALL = "󰉝"
var GLYPH_BASKETBALL = "󰠆"
var GLYPH_HOCKEY = "󰡺"
var GLYPH_BASEBALL = "󰡒"
var GLYPH_GOLF = "󰠣"
var GLYPH_COMBAT = "󰭥"
var GLYPH_MOTORSPORT = "󰈼"
var GLYPH_MEDAL = "󰦇"
var GLYPH_TROPHY = "󰔸"
var GLYPH_WHISTLE = "󰦶"
var GLYPH_ALERT = "󰀨"

function sportIdFromSlug(slug) {
  var idx = String(slug || "").indexOf("/")
  return idx === -1 ? String(slug || "") : String(slug).substring(0, idx)
}

// `groupId` (from Sports.js) is used when available, since it distinguishes
// e.g. Olympic basketball ("olympics") from regular basketball even though
// both slugs start with "basketball/". Falls back to the sport segment of
// the slug for custom leagues that aren't in the catalogue.
function glyphForLeague(slug, groupId) {
  switch (groupId || sportIdFromSlug(slug)) {
    case "soccer": return GLYPH_SOCCER
    case "hockey": return GLYPH_HOCKEY
    case "basketball": return GLYPH_BASKETBALL
    case "football": return GLYPH_FOOTBALL
    case "baseball": return GLYPH_BASEBALL
    case "golf": return GLYPH_GOLF
    case "racing": return GLYPH_MOTORSPORT
    case "mma": return GLYPH_COMBAT
    case "olympics": return GLYPH_MEDAL
    default: return GLYPH_TROPHY
  }
}

// Back-compat single-arg form used where only the slug is known (bar widget,
// live tab) — Olympic events just render with their underlying sport glyph.
function glyphForSlug(slug) {
  return glyphForLeague(slug, null)
}

function isLive(item) { return !!item && item.state === "in" }
function isUpcoming(item) { return !!item && item.state === "pre" }
function isFinished(item) { return !!item && item.state === "post" }
function isLeaderboard(item) { return !!item && item.kind === "leaderboard" }

function matchLabel(match) {
  if (!match) return ""
  return match.awayTeamAbbr + " " + match.awayScore + "-" + match.homeScore + " " + match.homeTeamAbbr
}

// Label used for notifications and any place a single line has to describe
// either shape of event (head-to-head match or leaderboard event).
function eventLabel(item) {
  if (!item) return ""
  if (isLeaderboard(item)) return item.name
  return matchLabel(item)
}

function shortTime(isoDate) {
  if (!isoDate) return ""
  var date = new Date(isoDate)
  if (isNaN(date.getTime())) return ""
  var hours = date.getHours()
  var minutes = date.getMinutes()
  return (hours < 10 ? "0" : "") + hours + ":" + (minutes < 10 ? "0" : "") + minutes
}

// YYYYMMDD in local time, the date format ESPN's scoreboard `dates` param
// expects.
function todayStamp() {
  var now = new Date()
  var y = now.getFullYear()
  var m = now.getMonth() + 1
  var d = now.getDate()
  return String(y) + (m < 10 ? "0" : "") + String(m) + (d < 10 ? "0" : "") + String(d)
}

// A match counts as "followed" when no specific team was picked for its
// league (following the whole league), or when one of the two sides is in
// the followed-team list. Leaderboard events (golf, racing, combat) have no
// team concept, so they're always considered followed once their league is.
function matchIsFollowed(match, followedTeamIds) {
  if (isLeaderboard(match)) return true
  if (!followedTeamIds || followedTeamIds.length === 0) return true
  return followedTeamIds.indexOf(match.homeTeamId) !== -1 || followedTeamIds.indexOf(match.awayTeamId) !== -1
}

// Olympic "teams" are national teams, so following a country filters by
// abbreviation (e.g. "FRA") rather than by team id — the same country's
// team carries a different numeric id per Olympic sport/league, but the
// same abbreviation. Empty selection = every country (general tracking).
function matchIsFollowedByCountry(match, followedCountryAbbrs) {
  if (isLeaderboard(match)) return true
  if (!followedCountryAbbrs || followedCountryAbbrs.length === 0) return true
  return followedCountryAbbrs.indexOf(match.homeTeamAbbr) !== -1 || followedCountryAbbrs.indexOf(match.awayTeamAbbr) !== -1
}

function groupByLeague(matches, leagueLabelFn) {
  var byLeague = ({})
  var order = []
  for (var i = 0; i < matches.length; i++) {
    var m = matches[i]
    if (!byLeague[m.leagueSlug]) {
      byLeague[m.leagueSlug] = { slug: m.leagueSlug, name: leagueLabelFn(m.leagueSlug), matches: [] }
      order.push(m.leagueSlug)
    }
    byLeague[m.leagueSlug].matches.push(m)
  }
  var out = []
  for (var j = 0; j < order.length; j++) out.push(byLeague[order[j]])
  return out
}
