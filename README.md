# Live Scores

An [Omarchy](https://omarchy.org) plugin: live scores, today's schedule, and
standings for soccer, hockey, basketball, American football, baseball, golf,
motorsport, and combat sports — men's, women's, and international
competitions — with a bar indicator and customizable notifications.

## Features

- **Live scores** — every live match, plus today's kickoffs still to come,
  organized by the leagues you follow. Team crests included.
- **Standings** — jump into any followed league's table at a glance.
- **Follow what you care about** — pick leagues from a built-in catalogue
  (organized by sport), narrow down to specific teams, or add any ESPN
  league not in the catalogue yourself.
- **Fast during the action** — polling automatically speeds up the moment
  a followed match goes live, so goals and score changes (and their
  notification) show up in seconds, not tens of seconds — then eases back
  off once nothing's live, to stay light on ESPN.
- **Notifications that stay out of your way** — turn them on or off per
  category (goals, key moments, score changes, kickoff/final whistle), and
  scope them to just your followed teams or a whole league.
- **Olympics tracking** — follow any live Olympic event and filter results
  by country, across every sport you've added, for the current Games.
- **Bar widget** — the score of your most relevant live match, right in
  the bar; click to open the full panel.
- **Choose your panel header** — the classic trophy icon, or a compact
  score/countdown widget (next followed kickoff today, or the live score)
  that expands into a fuller match card with one click.
- **Multilingual** — English, French, and Spanish, with a separate
  "Soccer" vs "Football" naming option since that's regional, not a
  translation.
- **Matches the rest of your desktop** — every sport icon follows your
  active Omarchy theme, light or dark, no emoji (team crests are the one
  exception — those are ESPN's real logos, shown as-is).

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
  (scores, standings, team lists, team crests) via `curl` subprocesses —
  one per followed league, fired in parallel, only while the plugin is
  enabled. No credentials, no writes.
- **Commands executed**: `curl` (ESPN requests) and, for notifications,
  `omarchy-notification-send` with a `notify-send` fallback if that binary
  isn't present.
- **Files**: reads/writes only its own `data/state.json` inside the
  plugin's directory (followed leagues/teams/countries, notification
  preferences). Nothing outside the plugin's own folder is touched.
- **Background behavior**: two polling timers while enabled — one for live
  matches (configurable idle rate, default 20s, automatically dropping to
  a faster configurable rate, default 5s, while a followed match is live),
  one for standings (configurable, default 5min).
- **No required external configuration** — everything is set from the
  panel.

## License

MIT — see [LICENSE](LICENSE).
