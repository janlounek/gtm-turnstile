# Privacy and data protection

Not legal advice. This is what the code actually does, so your DPO can decide what it
means for you.

## What leaves the browser

The bootstrap sends exactly one request per verification, to **your own tagging server**:

```
POST https://sgtm.example.com/tsv
v=1&t=<turnstile token>&a=<action>&r=<reason code>
```

No identifiers, no page URL, no referrer, no user data. When no token could be obtained
the request is still sent, with `t=none` and a reason code — that is what makes "no
signal" a measurable population rather than a hole in the data.

The browser also loads `https://challenges.cloudflare.com/turnstile/v0/api.js`, which is
Cloudflare's own challenge script and runs its own checks in the page.

## What your server sends to Cloudflare

One `POST` to `https://challenges.cloudflare.com/turnstile/v0/siteverify` per
verification, containing:

- your Turnstile **secret key**
- the token
- an **idempotency key** — a hash of the token, not of anything about the visitor
- the **visitor's IP address**, if *Send the visitor IP to Cloudflare* is on (it is by
  default)

That IP disclosure is the one item here that needs to appear in your records of
processing. Turn the option off if you would rather not make it; Cloudflare's assessment
gets slightly weaker, nothing breaks.

## What is stored on the device

Two first-party cookies, both scoped to your registrable domain and both expiring with
the verdict (30 minutes by default).

**`_tsv`** — the signed verdict. `HttpOnly`, `Secure`, `SameSite=Lax`. Contains:

```
1.k1.h.95.1757944800.1757946600.3f9a1c2b.0.7f3a91c2.<signature>
```

version, key id, verdict, score, issued-at, expires-at, **binding**, reason codes, a
token fingerprint, and the signature.

The **binding** is a truncated salted SHA-256 of the coarse IP (IPv4 `/24`, IPv6 first
four hextets) plus the user agent. The raw IP is never stored, the value is 8 hex
characters, and it is salted per installation — it exists so a cookie harvested from one
network is useless from another, not to identify anyone. A mismatch produces `unknown`
and a re-verification, never `bot`.

**`_tsv_st`** — the expiry timestamp alone. Readable by the page, no signature, no
payload. It exists purely so the browser can tell whether it needs a fresh challenge,
which is what lets `_tsv` stay `HttpOnly`.

Neither cookie contains a user identifier, and neither is readable across sites.

## Consent

**These templates do not gate on consent.** The web tag declares
`consentSettings: notNeeded` and the server client verifies regardless of consent state.

The reasoning is that the bot check itself is a security measure. You should know that
this is a position, not a settled fact — and that **enriching analytics with the result
is a different purpose from performing the check**. A regulator could reasonably accept
the first and not the second.

If you want the safer posture, two changes get you there:

- Fire the web tag on a consent-gated trigger instead of Initialisation, so no challenge
  runs before consent. (Mint the token *after* the CMP resolves, not before — a token is
  only valid for 300 seconds, and a slow consent interaction will expire it.)
- Apply the Augment Event transformation only when `analytics_storage` is granted, so the
  verdict never reaches GA4 without consent.

Either way, both cookies belong in your cookie policy. Suggested wording:

> **`_tsv`, `_tsv_st`** — Security. Records the result of an automated check that
> distinguishes human visitors from automated traffic, so that traffic statistics are not
> distorted by bots. Contains no identifier and cannot be read by other websites.
> Expires after 30 minutes.

## Data minimisation notes for reviewers

- Turnstile tokens are never logged and never placed in a URL, except by the last-resort
  `GET` transport used only when `sendBeacon` and `fetch` are both unavailable.
- The score and reason codes are the only things persisted; no raw siteverify response is
  stored.
- Nothing is written to Firestore, BigQuery or any external store by these templates.
- `metadata.ephemeral_id` (Cloudflare's Enterprise device identifier) is **not** used.
  If you enable it later, treat it as personal data: it is a pseudonymous per-site device
  identifier, and joining it to a user id would change the character of this system
  entirely.
