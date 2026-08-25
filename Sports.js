.pragma library

// Catalogue des ligues/compétitions couvertes par défaut, groupées par
// sport. `slug` = "{sportSlug}/{leagueSlug}", utilisé tel quel dans les
// URLs site.api.espn.com (voir Api.js). Ce catalogue est volontairement
// curé, pas exhaustif — l'onglet "Ligues & Équipes" permet d'ajouter
// n'importe quelle ligue ESPN non listée ici via son slug.
//
// `kind` distingue la forme des données ESPN pour ce sport :
//   "match"       (par défaut) deux camps, domicile/extérieur, score.
//   "leaderboard" un classement d'athlètes individuels (golf, sports
//                 mécaniques, combat) — pas d'équipes à suivre, pas de
//                 "domicile/extérieur".
// Absent = "match".

var SPORTS = [
  {
    id: "soccer",
    label: "Football / Soccer",
    leagues: [
      { slug: "soccer/eng.1", name: "Premier League", gender: "m", tier: "domestic" },
      { slug: "soccer/esp.1", name: "La Liga", gender: "m", tier: "domestic" },
      { slug: "soccer/ita.1", name: "Serie A", gender: "m", tier: "domestic" },
      { slug: "soccer/ger.1", name: "Bundesliga", gender: "m", tier: "domestic" },
      { slug: "soccer/fra.1", name: "Ligue 1", gender: "m", tier: "domestic" },
      { slug: "soccer/ned.1", name: "Eredivisie", gender: "m", tier: "domestic" },
      { slug: "soccer/por.1", name: "Primeira Liga", gender: "m", tier: "domestic" },
      { slug: "soccer/bra.1", name: "Brasileirão", gender: "m", tier: "domestic" },
      { slug: "soccer/usa.1", name: "MLS", gender: "m", tier: "domestic" },
      { slug: "soccer/mex.1", name: "Liga MX", gender: "m", tier: "domestic" },
      { slug: "soccer/uefa.champions", name: "Ligue des champions", gender: "m", tier: "international" },
      { slug: "soccer/uefa.europa", name: "Ligue Europa", gender: "m", tier: "international" },
      { slug: "soccer/uefa.europa.conf", name: "Ligue Conférence Europa", gender: "m", tier: "international" },
      { slug: "soccer/fifa.world", name: "Coupe du monde", gender: "m", tier: "international" },
      { slug: "soccer/uefa.euro", name: "Euro", gender: "m", tier: "international" },
      { slug: "soccer/conmebol.america", name: "Copa América", gender: "m", tier: "international" },
      { slug: "soccer/concacaf.gold", name: "Gold Cup", gender: "m", tier: "international" },
      { slug: "soccer/usa.nwsl", name: "NWSL", gender: "f", tier: "domestic" },
      { slug: "soccer/eng.w.1", name: "Women's Super League", gender: "f", tier: "domestic" },
      { slug: "soccer/uefa.wchampions", name: "Ligue des champions féminine", gender: "f", tier: "international" },
      { slug: "soccer/fifa.wwc", name: "Coupe du monde féminine", gender: "f", tier: "international" },
      { slug: "soccer/uefa.weuro", name: "Euro féminin", gender: "f", tier: "international" }
    ]
  },
  {
    id: "hockey",
    label: "Hockey sur glace",
    leagues: [
      { slug: "hockey/nhl", name: "NHL", gender: "m", tier: "domestic" },
      { slug: "hockey/pwhl", name: "PWHL", gender: "f", tier: "domestic" }
    ]
  },
  {
    id: "basketball",
    label: "Basketball",
    leagues: [
      { slug: "basketball/nba", name: "NBA", gender: "m", tier: "domestic" },
      { slug: "basketball/wnba", name: "WNBA", gender: "f", tier: "domestic" },
      { slug: "basketball/mens-college-basketball", name: "NCAA (H)", gender: "m", tier: "domestic" },
      { slug: "basketball/womens-college-basketball", name: "NCAA (F)", gender: "f", tier: "domestic" },
      { slug: "basketball/mens-euroleague", name: "EuroLeague", gender: "m", tier: "international" }
    ]
  },
  {
    id: "football",
    label: "Football américain",
    leagues: [
      { slug: "football/nfl", name: "NFL", gender: "m", tier: "domestic" },
      { slug: "football/college-football", name: "NCAA Football", gender: "m", tier: "domestic" }
    ]
  },
  {
    id: "baseball",
    label: "Baseball",
    leagues: [
      { slug: "baseball/mlb", name: "MLB", gender: "m", tier: "domestic" },
      { slug: "baseball/college-baseball", name: "NCAA Baseball", gender: "m", tier: "domestic" }
    ]
  },
  {
    id: "golf",
    label: "Golf",
    leagues: [
      { slug: "golf/pga", name: "PGA Tour", gender: "m", tier: "domestic", kind: "leaderboard" },
      { slug: "golf/lpga", name: "LPGA Tour", gender: "f", tier: "domestic", kind: "leaderboard" }
    ]
  },
  {
    id: "racing",
    label: "Sports mécaniques",
    leagues: [
      { slug: "racing/f1", name: "Formule 1", gender: "mixed", tier: "international", kind: "leaderboard" },
      { slug: "racing/nascar-premier", name: "NASCAR Cup Series", gender: "mixed", tier: "domestic", kind: "leaderboard" }
    ]
  },
  {
    id: "mma",
    label: "Sports de combat",
    leagues: [
      // ESPN n'expose pas la boxe comme sport à part sur cette API — l'UFC/MMA
      // est la donnée « combat » réellement disponible en direct. Une carte
      // de boxe précise peut être ajoutée en ligue personnalisée si ESPN lui
      // donne un jour un slug dédié.
      { slug: "mma/ufc", name: "UFC / MMA", gender: "mixed", tier: "international", kind: "leaderboard" }
    ]
  }
  // No "Olympics" group here on purpose. ESPN has no dedicated Olympics
  // sport bucket — it models each Olympic event under its normal sport
  // (e.g. "basketball/mens-olympics-basketball"), only while that edition's
  // Games are actually on, and the exact slug isn't consistent enough
  // across sports/editions to hardcode a reliable list (confirmed by
  // testing several plausible slugs: only Olympic basketball worked, and
  // only for the 2026 edition). The Olympics tab in Leagues & Teams lets a
  // user add whichever ESPN slug is live for the current Games instead —
  // see Service.addOlympicLeague().
]

function allLeagues() {
  var out = []
  for (var i = 0; i < SPORTS.length; i++) {
    var group = SPORTS[i]
    for (var j = 0; j < group.leagues.length; j++) {
      var league = group.leagues[j]
      out.push({
        slug: league.slug,
        name: league.name,
        sportId: group.id,
        sportLabel: group.label,
        gender: league.gender,
        tier: league.tier,
        kind: league.kind || "match"
      })
    }
  }
  return out
}

function leagueBySlug(slug) {
  var all = allLeagues()
  for (var i = 0; i < all.length; i++) if (all[i].slug === slug) return all[i]
  return null
}

// Falls back to the raw slug for a custom/unlisted league so the UI always
// has something readable to show.
function leagueLabel(slug) {
  var league = leagueBySlug(slug)
  return league ? league.name : String(slug)
}

// "match" for anything not in the catalogue (a custom league) — the safe
// default, since most sports ESPN covers are head-to-head.
function leagueKind(slug) {
  var league = leagueBySlug(slug)
  return league ? league.kind : "match"
}

