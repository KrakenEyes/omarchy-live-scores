# Live Scores

An [Omarchy](https://omarchy.org) plugin: live scores, today's schedule, and
standings for soccer, hockey, basketball, American football, baseball, golf,
motorsport, and combat sports — men's, women's, and international
competitions — with a bar indicator and customizable notifications.

## Features

- **Live** — live matches plus today's not-yet-started ones, grouped by
  followed league.
- **Standings** — pick any followed league, see its table.
- **Leagues & Teams** — follow leagues from a curated catalogue (grouped by
  sport), narrow a league down to specific teams, or add any ESPN league
  slug the catalogue doesn't cover.
- **Notifications** — master on/off plus per-category toggles (goals, key
  moments, score changes, kickoff/final whistle), scoped to followed teams
  only or any followed league.
- **Olympics** — no fixed league list (ESPN doesn't have one that stays
  valid across editions): add whichever Olympic event slug is live for the
  current Games, then filter by country across every Olympic event you've
  added at once.
- English, French, and Spanish UI, plus a separate "Soccer vs Football"
  naming preference (it's a regional split, not a translation).
- Bar pill with the score of the most relevant live match, click to open
  the panel.
- Every icon is a theme-colored glyph, not an emoji — the whole UI follows
  the active Omarchy theme, light or dark.

## Install

Review the repository, then add the plugin:

```bash
omarchy plugin add https://github.com/KrakenEyes/omarchy-live-scores.git
```

Accept the prompt to enable the plugin during installation.

For an unattended install from a repository you already trust:

```bash
omarchy plugin add https://github.com/KrakenEyes/omarchy-live-scores.git --enable --yes
```

## Update

Review and apply the next fast-forward update:

```bash
omarchy plugin update krakeneyes.live-scores
```

Or update all Git-managed plugins:

```bash
omarchy plugin update --all
```

## Validate from source

```bash
omarchy plugin validate .
```

## Configuration

Simple settings (refresh intervals, bar label, language, soccer/football
naming) live in the Notifications tab and are stored inline on the bar
widget's `shell.json` entry — also settable from the CLI, e.g.:

```bash
omarchy bar set krakeneyes.live-scores language fr
```

Everything else (followed leagues/teams/countries, notification
preferences) is edited from the panel itself and stored in this plugin's own
`data/state.json`, not versioned by Git.

## Data source

[ESPN](https://www.espn.com)'s public JSON API (`site.api.espn.com`) —
free, no key. It's not an official or documented API, so it can change
without notice. A couple of known gaps:

- No dedicated boxing endpoint — the "Combat sports" catalogue entry is
  UFC/MMA, the closest live combat-sports data ESPN actually exposes.
- No general Olympics/medal-table endpoint. ESPN models each Olympic sport
  under its normal sport bucket, only while that edition's Games are on —
  see the in-app help text in the Olympics section of Leagues & Teams.

## Security

This plugin runs unsandboxed inside `omarchy-shell`, like every Omarchy
plugin, once enabled. What it actually does:

- **Network**: read-only HTTPS GET requests to `site.api.espn.com`
  (scores, standings, team lists) via `curl` subprocesses — one per
  followed league, only while the plugin is enabled. No credentials, no
  writes.
- **Commands executed**: `curl` (ESPN requests) and, for notifications,
  `omarchy-notification-send` with a `notify-send` fallback if that binary
  isn't present.
- **Files**: reads/writes only its own `data/state.json` inside the
  plugin's directory (followed leagues/teams/countries, notification
  preferences). Nothing outside the plugin's own folder is touched.
- **Background behavior**: two polling timers while enabled — one for live
  matches (configurable, default 20s, only for leagues with a match today),
  one for standings (configurable, default 5min).
- **No required external configuration** — everything is set from the
  panel.

## License

MIT — see [LICENSE](LICENSE).
