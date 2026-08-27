# Live Scores

An [Omarchy](https://omarchy.org) plugin for live scores, schedules, and standings. Covers
soccer, hockey, basketball, football, baseball, golf, motorsport, and combat sports. Includes
a bar indicator and notifications.

## Features

- **Live scores**: live matches and today's kickoffs, grouped by league. Team crests included.
- **Standings**: the table for any league you follow.
- **Follow what you care about**: pick leagues from the built-in list, narrow down to specific
  teams, or add any ESPN league yourself.
- **Fast when it matters**: checks scores more often during live matches, so goals and score
  changes show up fast. Slows back down once nothing's live.
- **Notifications**: turn on goals, key moments, score changes, and kickoff/final whistle. Set
  them per team or per league.
- **Olympics tracking**: follow live Olympic events and filter by country.
- **Bar widget**: your most relevant live match, right in the bar. Click to open the full panel.
- **Panel header**: choose the trophy icon or a compact score/countdown widget.
- **Multilingual**: English, French, and Spanish. Option to use "Football" instead of "Soccer".
- **Matches your theme**: icons follow your Omarchy theme, light or dark. Team crests are real
  logos.

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
  followed league, fired in parallel, only while the plugin is enabled,
  capped at 5 MiB and an 8s timeout per request. No credentials, no
  writes. Team crest images are the one exception to the `curl` path:
  they're loaded directly by Qt's own `Image` element (not size/timeout
  capped the way the `curl` calls are), restricted to `https://` URLs on
  ESPN's own logo CDN (`*.espncdn.com`) only.
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
