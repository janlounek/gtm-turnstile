# Setup

About 20 minutes end to end. Do the parts in order — the web tag cannot work until the
server client is publishing the bootstrap script.

## 0. Before you start

Check one thing first, because it decides whether any of this can work:

> Is your server-side GTM container on the **same registrable domain** as the website?
> `sgtm.example.com` serving `www.example.com` — yes. `gtm.my-vendor.io` serving
> `example.com` — no.

If not, the verdict cookie is a third-party cookie and Safari, Firefox and any Chrome
user with third-party cookies disabled will discard it. Fix the tagging server's domain
before continuing; nothing else in this document will help.

## 1. Create the Turnstile widget

In the Cloudflare dashboard, **Turnstile → Add widget**:

- **Hostnames** — every hostname the widget will run on. This list matters more than it
  looks; see step 3.
- **Widget mode** — *Managed* is the right default. The bootstrap renders it with
  `execution: 'execute'` and `appearance: 'interaction-only'`, so nothing is visible
  unless Turnstile decides a person genuinely has to click something.

Keep the **site key** (public, goes in the web container) and the **secret key**
(goes only in the server container).

## 2. Import the templates

**Server container** → Templates → *Client Templates* → New → ⋮ → Import →
`templates/server/turnstile-verify-client.tpl`. Save.

**Server container** → Templates → *Variable Templates* → New → ⋮ → Import →
`templates/server/turnstile-verdict-variable.tpl`. Save.

**Web container** → Templates → *Tag Templates* → New → ⋮ → Import →
`templates/web/turnstile-bot-signal-tag.tpl`. Save.

Then, in the web template's **Permissions** tab, find *Injects Scripts* and replace
`https://*` with your own tagging-server origin, e.g. `https://sgtm.example.com/`. The
template ships permissive because your endpoint cannot be known in advance; narrowing it
takes ten seconds and is worth doing.

## 3. Configure the server client

Server container → **Clients** → New → *Cloudflare Turnstile Verify*. Give it a
**priority above 0** so it is offered the request before the GA4 client.

| Field | Value |
|---|---|
| Request path to claim | `/tsv` |
| Secret key | the Turnstile **secret** key |
| Allowed hostnames | every hostname from step 1 |
| Expected action | `page_view` |
| Signing key | a long random string you invent — see below |
| Key ID | `k1` |
| Binding salt | another random string |

Generate the two secrets with something like:

```bash
openssl rand -hex 32
```

**The allowed hostnames list is the check that matters.** The site key is public, so an
attacker can put your widget on their own page and mint tokens that verify perfectly.
`success: true` from a hostname you did not list is the single strongest bot signal
siteverify actually gives you — and it only works if the list is accurate. Add every
legitimate hostname, exactly as Turnstile reports it.

Leave the defaults alone unless you have a reason: 1800-second verdict lifetime, 1500 ms
siteverify timeout, 120-second maximum challenge age, client binding on.

## 4. Configure the verdict variable

Server container → **Variables** → New → *Turnstile Verdict*.

| Field | Value |
|---|---|
| Output | All fields (object) |
| Verdict cookie name | `_tsv` |
| Signing keys | one row: `k1` + **the same signing key as the client** |
| Binding salt | **the same salt as the client** |

Name it something like `Turnstile Verdict`.

If the signing key, key ID, cookie name or salt differ by a single character, every
cookie fails verification and every visitor reads back as `unknown`. That failure looks
like a data problem, not a configuration problem, so check it now: step 7 tells you how.

## 5. Add the web tag

Web container → **Tags** → New → *Turnstile Bot Signal*.

| Field | Value |
|---|---|
| Verification endpoint | `https://sgtm.example.com/tsv` |
| Turnstile site key | the **site** key |
| Action | `page_view` (must match the client's *Expected action*) |

Trigger: **Initialisation — All Pages**. Once per page is enough; the bootstrap decides
for itself whether a fresh challenge is actually needed.

## 6. Put the verdict on your events

Server container → **Transformations** → New → **Augment Event**.

Add parameters mapped to the variable's fields — or, simplest, set the whole
`Turnstile Verdict` variable as an augmentation so every `tsv_*` field is written onto
every event. Apply it to *All tags* (or just your GA4 tag).

Nothing else changes. Your GA4 tag now forwards `tsv_verdict`, `tsv_score_bucket` and the
rest without being edited.

In GA4, register `tsv_verdict` and `tsv_score_bucket` as custom dimensions. Send the
**bucket**, not the raw score — a 0–100 integer as a custom dimension is 101 distinct
values of cardinality for no analytical gain. Keep the raw score for BigQuery.

## 7. Verify it actually works

**Publish both containers first** — server preview alone will not serve `/tsv.js`.

Confirm the bootstrap is being served:

```bash
curl -sI https://sgtm.example.com/tsv.js
```

Expect `200` and `content-type: text/javascript`.

Turn on **Return the verdict as JSON** in the client temporarily, then load the site with
the browser console open. You should see:

1. A request to `challenges.cloudflare.com/turnstile/v0/api.js`.
2. A `POST` to `/tsv`.
3. `_tsv` and `_tsv_st` in Application → Cookies.

Then check the round trip end to end, which is the step that catches a mismatched signing
key:

- In server container **Preview**, load the site and find the `turnstile_verification`
  event. Its `tsv_verdict` should be `h`.
- Navigate to another page and find the GA4 event. The variable should resolve to
  `tsv_verdict: human` with a score of 95.

If the first is `h` but the second is `unknown` with `tsv_reasons: bm`, the client and the
variable disagree about the signing key, key ID, cookie name or binding salt. Re-check
step 4.

Finally, prove the negative cases:

```bash
# No token at all -> unknown with a reason, not a low score
curl -s -X POST https://sgtm.example.com/tsv --data 'v=1&t=none&a=page_view&r=sb'
# => {"verdict":"u","score":null,"reasons":["sb"], ...}
```

Take a real token from the browser's network tab and replay it twice: the first call
should return `h`, the second `s` with `["rp"]` — that is Turnstile's single-use
enforcement working.

Turn off **Return the verdict as JSON** when you are done.

## Rotating the signing key

1. Add the new key as a second row in the variable's key table. Publish.
2. Change the client's **Key ID** and **Signing key** to the new pair. Publish.
3. Once the old verdict lifetime has elapsed (30 minutes by default), delete the old row.

Doing it in that order means no visitor ever presents a cookie the variable cannot verify.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Everyone is `unknown`, `tsv_reasons: bm` | Signing key, key ID, cookie name or salt differ between client and variable |
| Everyone is `unknown`, `tsv_reasons: nh` | No verdict cookie arriving — check the tagging server shares a registrable domain with the site |
| Everyone is `error`, `tsv_reasons: cfg` | Wrong Turnstile secret key. Worth an alert: at this point 100% of traffic scores identically and the data is worthless |
| Lots of `suspect` / `rp` | Tokens being replayed — usually a tag firing more than once per page, a bfcache restore, or prerendering |
| Lots of `unknown` / `sb` | `challenges.cloudflare.com` blocked, by an ad blocker or by your own CSP |
| Lots of `suspect` / `am` | The web tag's *Action* and the client's *Expected action* do not match |
| Everything is `bot` / `hm` | The hostname Turnstile reports is not in the allowed list — check for `www` versus apex |
| The tag reports failure in preview | The *Injects Scripts* permission was never narrowed to your endpoint, or was narrowed wrongly |
