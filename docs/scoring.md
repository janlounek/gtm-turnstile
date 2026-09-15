# Scoring

## What the number means

`tsv_score` is **confidence that this hit came from a verified human**, 0–100.

The direction is deliberate. A "bot probability" invites you to treat a missing signal as
evidence of a bot, and the missing-signal population is dominated by privacy-conscious
people, ad-blocker users and anyone on a corporate network that blocks Cloudflare. A
confidence score has an honest answer for those cases: *we do not know*.

So there are five verdicts, and two of them carry no score at all.

| `tsv_verdict` | Meaning |
|---|---|
| `human` | Challenge solved, on one of your hostnames, recently |
| `suspect` | Solved, but something about the context is off |
| `bot` | Positive evidence of forgery, or a token minted somewhere else |
| `unknown` | No usable signal arrived |
| `error` | **We** are broken — misconfiguration, or Cloudflare unreachable |

`unknown` and `error` have `tsv_score = undefined`, never `0`. Collapsing them into a low
score is the mistake that turns this into a machine for mislabelling real people.

## The rubric

| Condition | Score | Verdict | Reason |
|---|---|---|---|
| Solved, hostname allowed, action matches, challenge < 60 s old | 95 | `human` | |
| …challenge 60–120 s old | 90 | `human` | |
| …challenge older than the configured maximum | 85 | `human` | `st` |
| Solved, but hostname **not** in the allowed list | 25 | `bot` | `hm` |
| Solved, hostname allowed, action does not match | 60 | `suspect` | `am` |
| `invalid-input-response` — the token is forged or corrupt | 10 | `bot` | `fg` |
| `timeout-or-duplicate` — the token was already spent | 30 | `suspect` | `rp` |
| No token sent, or `missing-input-response` | — | `unknown` | `nh` |
| Browser reported the challenge script was blocked | — | `unknown` | `sb` |
| Browser reported the challenge timed out | — | `unknown` | `to` |
| Browser reported a Turnstile error | — | `unknown` | `er` |
| `missing-input-secret`, `invalid-input-secret`, `bad-request` | — | `error` | `cfg` |
| `internal-error`, or siteverify unreachable | — | `error` | `net` |
| Verdict cookie fails signature, binding or format checks | — | `unknown` | `bm` |

Hostname is checked **before** action, so a token minted on an attacker's page can never
downgrade to merely `suspect`.

### Why `timeout-or-duplicate` is only `suspect`

It is what a replayed token looks like — and also what a double-firing tag, a bfcache
restore and a prerendered page look like. The client sends an `idempotency_key` derived
from the token so a network-level retry does not land here, but the legitimate causes are
common enough that `bot` would be wrong.

### Why a bad secret key is `error`, not `bot`

If the secret is wrong, 100% of traffic scores identically and your data is worthless.
That deserves an alert, not a bot label. Point a monitoring tag at the
`turnstile_verification` event and alert on `tsv_reasons` containing `cfg`.

## Fields

With **Output: All fields**, the variable returns:

| Field | Type | Notes |
|---|---|---|
| `tsv_verdict` | string | `human` / `suspect` / `bot` / `unknown` / `error` |
| `tsv_score` | number \| undefined | 0–100; undefined for `unknown` and `error` |
| `tsv_score_bucket` | string | `0-19` … `80-100`, or `none`. **Send this to GA4.** |
| `tsv_reasons` | string | `-`-joined codes from the table above |
| `tsv_source` | string | `cookie` or `none` |
| `tsv_age_s` | number | Seconds since the verdict was issued |
| `tsv_v` | number | Template version, so you can reinterpret historical data |

Send `tsv_score_bucket` to GA4 rather than `tsv_score`: a 0–100 integer as a custom
dimension is 101 distinct values for no analytical gain. Keep the raw score for BigQuery.

## Reading the data

**The per-visitor label is rarely the interesting part.** For a single session it is one
weak signal, and acting on it individually is how you end up excluding real customers.

The useful number is the **rate of each verdict, per segment**. A referrer whose
`unknown` rate is 90% when your site average is 15% is a finding. A campaign whose `bot`
rate jumps from 2% to 40% overnight is a finding. One visitor scoring 30 is noise.

Some starting points:

- **Baseline first.** Run for a week before concluding anything. A healthy site typically
  shows most traffic as `human`, a meaningful tail of `unknown`, and very little `bot`.
- **Segment by source/medium.** This is where paid-traffic quality problems show up.
- **Watch `unknown` as a rate, not a nuisance.** It is a real population — ad blockers,
  strict CSPs, JavaScript-disabled clients — and a sudden shift in it usually means
  something changed in your own setup, not in your traffic.
- **Never build an audience or a conversion definition on `bot`.** The false-positive
  cost is a real customer excluded from remarketing, and the signal is not strong enough
  to carry that.

## Changing the rubric

The scores live in one place: [`src/shared/scoring.js`](../src/shared/scoring.js). Edit
the constants there, run `npm test` (the rubric has a test per row), then `npm run build`
to regenerate the templates. Never edit the copy inside a `.tpl`; CI will fail.

If you change the numbers, bump `TEMPLATE_VERSION` in the variable so `tsv_v` lets you
tell old data from new.
