# gtm-turnstile

Cloudflare Turnstile bot detection for **web + server-side Google Tag Manager**, as three
importable GTM templates.

The browser solves an invisible Turnstile challenge once per session. Your server
container verifies the token, composes a human-confidence score, and stores it in a
signed first-party cookie. Every later hit reads that cookie synchronously, so your GA4
events arrive carrying `tsv_verdict` and `tsv_score` with no extra latency.

```
Browser (web GTM)                 Server GTM                         Consumers
─────────────────                 ──────────                         ─────────
[Tag] Turnstile Bot Signal
  writes config, loads ──────────▶ GET  /tsv.js   first-party bootstrap
  the first-party bootstrap
        │
        │ bootstrap: invisible challenge → token
        ▼
  sendBeacon ─────────────────────▶ POST /tsv     [Client] Turnstile Verify
                                                    siteverify + score
                                                    Set-Cookie _tsv   (signed, HttpOnly)
                                                    Set-Cookie _tsv_st (expiry only)

GA4 / Ads hit ───────────────────▶ [Client] Google Analytics: GA4  (unchanged)
                                        │
                                        ├─ [Variable] Turnstile Verdict
                                        │     reads _tsv, verifies the signature
                                        │
                                        └─ Augment Event transformation
                                              adds tsv_* to every event ──▶ GA4, BigQuery
```

## What this is, and what it is not

**Turnstile does not return a bot score.** Its `siteverify` API returns pass/fail plus
`challenge_ts`, `hostname`, `action` and `error-codes`. The 0–100 number here is composed
by the server client from that verdict plus replay, freshness, hostname and action
checks. It is *confidence that a hit came from a verified human* — not a Cloudflare bot
score.

**It is not a security control.** A bot that never sends the verification hit produces no
signal at all. That is not a bug to be fixed at the tag-manager layer; it is the shape of
the problem. Enrich your data with this, segment reports with it, alert on changes in its
distribution — but never gate anything valuable on a good verdict. Real enforcement
belongs at the edge (Cloudflare WAF, Bot Management, Turnstile pre-clearance).

**The population it scores is already narrow.** Bots that do not execute JavaScript never
reach GA4 in the first place. Turnstile's marginal value here is discriminating headless
and automation stacks *within* JavaScript-capable traffic. Real, but narrower than "bot
detection" sounds.

**The site key is public.** Anyone can embed it on their own page and mint tokens that
verify successfully, so `success: true` alone proves very little. The allowed-hostname
check is what the score actually rests on — which is why that field is required.

### The obvious gap, and how to close it

Everything above is opt-in for the attacker: any signal the client chooses whether to
send is a signal the attacker chooses not to send. The natural extension is a **passive
layer** scoring request headers (`sec-ch-ua` consistency, missing `accept-language`,
`sec-fetch-site` on hits that should be same-origin, user-agent contradictions). Those
arrive on every hit including from bots that skip the beacon, they are readable
synchronously in the verdict variable with zero HTTP calls, and they would give the
package 100% coverage at lower precision. This release deliberately scopes to Turnstile
signals only; the passive layer is the first thing to add.

## The three templates

| File | Container | Type | Job |
|---|---|---|---|
| [`templates/web/turnstile-bot-signal-tag.tpl`](templates/web/turnstile-bot-signal-tag.tpl) | Web | Tag | Writes config and loads the first-party bootstrap |
| [`templates/server/turnstile-verify-client.tpl`](templates/server/turnstile-verify-client.tpl) | Server | Client | Serves the bootstrap, verifies tokens, signs the verdict cookie |
| [`templates/server/turnstile-verdict-variable.tpl`](templates/server/turnstile-verdict-variable.tpl) | Server | Variable | Verifies and exposes the verdict to tags and transformations |

Start with **[docs/setup.md](docs/setup.md)**. Then
[docs/scoring.md](docs/scoring.md) for what the numbers mean and
[docs/privacy.md](docs/privacy.md) for what gets sent where.

## Two design constraints worth knowing before you read the code

**A server GTM variable cannot await anything.** `sendHttpRequest`, `Firestore.read` and
`sha256` all return Promises; a variable must return synchronously. `getCookieValues` and
`sha256Sync` are the only primitives that can produce a verified verdict inside one. So
"verify out of band, persist a signed cookie, read it synchronously" is not one option
among several — it is the only shape that works with transformations.

**A web template cannot touch the DOM.** GTM's `access_globals` permission rejects any
path whose first token is a predefined browser global, which rules out both `document.*`
and `navigator.sendBeacon`. A web template therefore cannot create the widget container
*or* beacon the token. That is why the server client serves a first-party bootstrap
script and the web tag is a thin shim: the bootstrap is ordinary page JavaScript with no
sandbox restrictions, and it is same-site with the endpoint that sets the cookie.

## Development

```bash
npm test          # codec, scoring rubric, and .tpl structural validation
npm run build     # regenerate the inlined blocks in the .tpl files from src/
npm run check     # fail if a .tpl has drifted from src/
npm run verify    # check + test, as CI runs it
```

`src/shared/verdict-codec.js` and `src/shared/scoring.js` are the canonical
implementations, written in the GTM sandboxed-JavaScript subset so the same bytes run in
the sandbox and under Node. `build/generate-tpl.js` inlines them into the templates,
because GTM has no import mechanism and the signing and verifying code must stay
byte-identical — a single divergent character would make every cookie fail verification
and silently turn every visitor into `unknown`. CI fails if you edit a generated block by
hand.

The `.tpl` files also carry their own `___TESTS___`, which run inside the GTM template
editor ("Run tests" in the Tests tab) against GTM's own API mocks.

## Requirements

- A Cloudflare Turnstile widget (the free plan is enough; 20 widgets per account).
- A server-side GTM container **on the same registrable domain as the website** — a
  cross-site tagging server cannot set a usable verdict cookie.
- A CSP that allows your tagging server and `https://challenges.cloudflare.com` for both
  `script-src` and `frame-src`.

## Licence

MIT
