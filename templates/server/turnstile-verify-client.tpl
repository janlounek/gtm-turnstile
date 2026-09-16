___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "CLIENT",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Cloudflare Turnstile Verify",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Verifies a Cloudflare Turnstile token, composes a human-confidence score, and stores it in a signed first-party cookie for later hits to read. Also serves the first-party browser bootstrap script.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "GROUP",
    "name": "endpointGroup",
    "displayName": "Endpoint",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "TEXT",
        "name": "claimPath",
        "displayName": "Request path to claim",
        "simpleValueType": true,
        "defaultValue": "/tsv",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "The client claims POST and GET on this exact path. The bootstrap script is served from the same path with <code>.js</code> appended (<code>/tsv.js</code>). Pick something that cannot collide with another client."
      },
      {
        "type": "CHECKBOX",
        "name": "serveBootstrap",
        "checkboxText": "Serve the browser bootstrap script",
        "simpleValueType": true,
        "defaultValue": true,
        "help": "Serves the first-party script the web tag injects. Turn this off only if you host the script yourself."
      },
      {
        "type": "TEXT",
        "name": "bootstrapCacheSeconds",
        "displayName": "Bootstrap cache lifetime (seconds)",
        "simpleValueType": true,
        "defaultValue": "3600",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ],
        "enablingConditions": [
          {
            "paramName": "serveBootstrap",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "turnstileGroup",
    "displayName": "Cloudflare Turnstile",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "TEXT",
        "name": "secretKey",
        "displayName": "Secret key",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "The Turnstile widget's secret key. Never the site key — that one is public."
      },
      {
        "type": "SIMPLE_TABLE",
        "name": "allowedHostnames",
        "displayName": "Allowed hostnames",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "Hostname",
            "name": "hostname",
            "type": "TEXT",
            "isUnique": true
          }
        ],
        "valueValidators": [
          {
            "type": "TABLE_ROW_COUNT",
            "args": [
              1
            ]
          }
        ],
        "help": "Required. The site key is public, so anyone can embed it on their own page and mint tokens that verify successfully. A token whose hostname is not listed here scores as a bot — this check, not <code>success: true</code>, is what the score actually rests on. List every hostname the widget legitimately runs on, exactly as Turnstile reports it."
      },
      {
        "type": "TEXT",
        "name": "expectedAction",
        "displayName": "Expected action",
        "simpleValueType": true,
        "defaultValue": "page_view",
        "help": "Must match the action the web tag sends. Leave empty to accept any action."
      },
      {
        "type": "TEXT",
        "name": "maxChallengeAge",
        "displayName": "Maximum challenge age (seconds)",
        "simpleValueType": true,
        "defaultValue": "120",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ],
        "help": "Challenges older than this still pass, but lose points and gain the <code>st</code> reason code."
      },
      {
        "type": "TEXT",
        "name": "siteverifyTimeout",
        "displayName": "Siteverify timeout (ms)",
        "simpleValueType": true,
        "defaultValue": "1500",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ]
      },
      {
        "type": "CHECKBOX",
        "name": "sendRemoteIp",
        "checkboxText": "Send the visitor IP to Cloudflare",
        "simpleValueType": true,
        "defaultValue": true,
        "help": "Improves Cloudflare's own assessment. It also means the visitor IP is disclosed to Cloudflare — note it in your records of processing, or turn this off."
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "cookieGroup",
    "displayName": "Verdict cookie",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "macSecret",
        "displayName": "Signing key",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "A long random string of your own, unrelated to the Turnstile secret. It authenticates the verdict cookie; without it a visitor could simply write themselves a 'human' verdict. The Turnstile Verdict variable must be configured with the same key."
      },
      {
        "type": "TEXT",
        "name": "keyId",
        "displayName": "Key ID",
        "simpleValueType": true,
        "defaultValue": "k1",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "Stamped into the cookie so keys can be rotated: add the new key to the variable's key table first, then switch this, then drop the old key once the old cookies have expired."
      },
      {
        "type": "TEXT",
        "name": "cookieName",
        "displayName": "Verdict cookie name",
        "simpleValueType": true,
        "defaultValue": "_tsv",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ]
      },
      {
        "type": "TEXT",
        "name": "stateCookieName",
        "displayName": "State cookie name",
        "simpleValueType": true,
        "defaultValue": "_tsv_st",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "Holds only the expiry timestamp and is readable by the page, so the browser knows whether it needs a fresh challenge. This is what lets the verdict cookie itself stay HttpOnly."
      },
      {
        "type": "TEXT",
        "name": "cookieTtl",
        "displayName": "Verdict lifetime (seconds)",
        "simpleValueType": true,
        "defaultValue": "1800",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ],
        "help": "How long one verification covers. 1800 matches a typical GA4 session timeout."
      },
      {
        "type": "TEXT",
        "name": "cookieDomain",
        "displayName": "Cookie domain",
        "simpleValueType": true,
        "defaultValue": "auto",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "help": "<code>auto</code> uses the effective top-level domain plus one."
      },
      {
        "type": "CHECKBOX",
        "name": "bindEnabled",
        "checkboxText": "Bind the verdict to the requesting client",
        "simpleValueType": true,
        "defaultValue": true,
        "help": "Stores a truncated hash of the coarse IP (IPv4 /24, IPv6 /64) and user agent, so a harvested cookie is useless from another network. The raw IP is never stored. A mismatch yields <em>unknown</em> and a re-verification, never <em>bot</em> — real people change networks."
      },
      {
        "type": "TEXT",
        "name": "bindSalt",
        "displayName": "Binding salt",
        "simpleValueType": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ],
        "enablingConditions": [
          {
            "paramName": "bindEnabled",
            "paramValue": true,
            "type": "EQUALS"
          }
        ],
        "help": "Any random string. Must match the Turnstile Verdict variable."
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "advancedGroup",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "emitEvent",
        "checkboxText": "Emit a container event for each verification",
        "simpleValueType": true,
        "defaultValue": true,
        "help": "Gives you somewhere to hang a BigQuery tag or an alert on <code>cfg</code> verdicts."
      },
      {
        "type": "TEXT",
        "name": "eventName",
        "displayName": "Event name",
        "simpleValueType": true,
        "defaultValue": "turnstile_verification",
        "enablingConditions": [
          {
            "paramName": "emitEvent",
            "paramValue": true,
            "type": "EQUALS"
          }
        ]
      },
      {
        "type": "CHECKBOX",
        "name": "debugResponse",
        "checkboxText": "Return the verdict as JSON",
        "simpleValueType": true,
        "defaultValue": false,
        "help": "Useful while setting up — curl the endpoint and read the verdict back. The page never needs this, so turn it off in production."
      },
      {
        "type": "CHECKBOX",
        "name": "debugLogging",
        "checkboxText": "Log to the console in preview mode",
        "simpleValueType": true,
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const claimRequest = require('claimRequest');
const returnResponse = require('returnResponse');
const setResponseBody = require('setResponseBody');
const setResponseHeader = require('setResponseHeader');
const setResponseStatus = require('setResponseStatus');
const setCookie = require('setCookie');
const getRequestPath = require('getRequestPath');
const getRequestMethod = require('getRequestMethod');
const getRequestBody = require('getRequestBody');
const getRequestQueryParameters = require('getRequestQueryParameters');
const getRequestHeader = require('getRequestHeader');
const getRemoteAddress = require('getRemoteAddress');
const sendHttpRequest = require('sendHttpRequest');
const runContainer = require('runContainer');
const sha256Sync = require('sha256Sync');
const generateRandom = require('generateRandom');
const getTimestampMillis = require('getTimestampMillis');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const makeInteger = require('makeInteger');
const encodeUriComponent = require('encodeUriComponent');
const decodeUriComponent = require('decodeUriComponent');
const JSON = require('JSON');
const logToConsole = require('logToConsole');

const SITEVERIFY = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

// >>> GENERATED src/shared/verdict-codec.js
// Turnstile verdict cookie codec — CANONICAL SOURCE.
//
// This file is inlined verbatim into BOTH server templates by build/generate-tpl.js:
//   - turnstile-verify-client.tpl    (signs the cookie)
//   - turnstile-verdict-variable.tpl (verifies the cookie)
// A single divergent character between signer and verifier makes every cookie fail
// validation and silently turns every visitor into `unknown`. Never edit the copy
// inside a .tpl — edit here and re-run `npm run build`.
//
// Written in the GTM sandboxed-JavaScript subset so the same bytes run in the sandbox
// and in Node:
//   allowed : var/let/const, arrow functions, ES5.1 builtins on String/Array
//   banned  : new, this, window, document, RegExp, Date, Math, try/catch, classes,
//             template literals, destructuring, spread, for...of
// Anything the sandbox does not provide is passed in via `deps`:
//   deps.sha256hex(str) -> lowercase hex digest
//   deps.toNumber(str)  -> number
//   deps.nonce()        -> unpredictable string, used to blind digest comparison

var TSV_VERSION = '1';
var TSV_SEGMENTS = 10;
var TSV_MAC_LEN = 32;
var TSV_DOMAIN_TAG = 'tsvc1';
var TSV_SAFE_CHARS =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
var TSV_DIGITS = '0123456789';

// ---------------------------------------------------------------------------
// primitives
// ---------------------------------------------------------------------------

// Every cookie segment is restricted to [A-Za-z0-9_-] on write AND on read. Without
// this, a '.' smuggled into `reasons` would shift field boundaries while leaving the
// MAC valid — the same payload would authenticate under two different parses.
var tsvIsSafe = function (s) {
  if (typeof s !== 'string' || s.length === 0) return false;
  for (var i = 0; i < s.length; i++) {
    if (TSV_SAFE_CHARS.indexOf(s.charAt(i)) === -1) return false;
  }
  return true;
};

var tsvIsDigits = function (s) {
  if (typeof s !== 'string' || s.length === 0) return false;
  for (var i = 0; i < s.length; i++) {
    if (TSV_DIGITS.indexOf(s.charAt(i)) === -1) return false;
  }
  return true;
};

// Unix seconds as a fixed-width 10-digit string, so lexicographic comparison equals
// numeric comparison (holds until year 2286) and the codec never has to parse a number
// just to answer "is this expired?".
var tsvPad10 = function (n) {
  var s = '' + n;
  while (s.length < 10) s = '0' + s;
  return s.length > 10 ? s.substring(s.length - 10) : s;
};

// Nested hash. A bare sha256(secret + payload) is forgeable here: SHA-256 length
// extension plus a last-value-wins parser lets an attacker append their own fields.
// Hashing the inner digest under the secret again removes that — the attacker never
// sees H(secret||payload), and the outer input is a fixed-length digest.
var tsvMac = function (deps, secret, kid, payload) {
  var inner = deps.sha256hex(secret + '|' + TSV_DOMAIN_TAG + '|' + kid + '|' + payload);
  return deps.sha256hex(secret + '|' + inner).substring(0, TSV_MAC_LEN);
};

// Blinded comparison: hashing both sides under a fresh nonce before comparing means
// a '===' short-circuit leaks nothing about how many leading characters matched.
var tsvSafeEqual = function (deps, a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  var n = deps.nonce();
  return deps.sha256hex(n + '|' + a) === deps.sha256hex(n + '|' + b);
};

// ---------------------------------------------------------------------------
// encode
// ---------------------------------------------------------------------------

// fields: { kid, secret, verdict, score (0-100 or null), iat, exp, bind, reasons[], jti }
// Returns the cookie value, or '' if anything is malformed — callers must treat ''
// as "do not set a cookie" rather than shipping an unauthenticated value.
var tsvEncode = function (deps, fields) {
  var score = fields.score === null || fields.score === undefined ? 'na' : '' + fields.score;
  var reasons =
    !fields.reasons || fields.reasons.length === 0 ? '0' : fields.reasons.join('-');
  var bind = fields.bind ? fields.bind : '0';

  var parts = [
    TSV_VERSION,
    '' + fields.kid,
    '' + fields.verdict,
    score,
    tsvPad10(fields.iat),
    tsvPad10(fields.exp),
    bind,
    reasons,
    '' + fields.jti
  ];

  for (var i = 0; i < parts.length; i++) {
    if (!tsvIsSafe(parts[i])) return '';
  }

  var payload = parts.join('.');
  return payload + '.' + tsvMac(deps, fields.secret, '' + fields.kid, payload);
};

// ---------------------------------------------------------------------------
// decode
// ---------------------------------------------------------------------------

// opts: { value, keys: [{kid, secret}], nowSec }
// Always returns an object. `ok:false` carries a machine-readable `error`; it never
// throws, because the sandbox has no try/catch to catch it with.
var tsvDecode = function (deps, opts) {
  var out = { ok: false, error: 'absent' };

  var value = opts.value;
  if (typeof value !== 'string' || value.length === 0) return out;
  if (value.length > 512) {
    out.error = 'malformed';
    return out;
  }

  var parts = value.split('.');
  if (parts.length !== TSV_SEGMENTS) {
    out.error = 'malformed';
    return out;
  }

  var i;
  for (i = 0; i < TSV_SEGMENTS - 1; i++) {
    if (!tsvIsSafe(parts[i])) {
      out.error = 'malformed';
      return out;
    }
  }
  if (parts[0] !== TSV_VERSION) {
    out.error = 'version';
    return out;
  }

  var kid = parts[1];
  var secret = null;
  for (i = 0; i < opts.keys.length; i++) {
    if (opts.keys[i].kid === kid) {
      secret = opts.keys[i].secret;
      break;
    }
  }
  if (secret === null) {
    out.error = 'unknown_kid';
    return out;
  }

  var payload = parts.slice(0, TSV_SEGMENTS - 1).join('.');
  if (!tsvSafeEqual(deps, parts[TSV_SEGMENTS - 1], tsvMac(deps, secret, kid, payload))) {
    out.error = 'bad_mac';
    return out;
  }

  var iat = parts[4];
  var exp = parts[5];
  if (!tsvIsDigits(iat) || !tsvIsDigits(exp) || iat.length !== 10 || exp.length !== 10) {
    out.error = 'malformed';
    return out;
  }
  // Fixed-width decimal strings compare lexicographically the way the numbers do.
  if (tsvPad10(opts.nowSec) >= exp) {
    out.error = 'expired';
    return out;
  }

  return {
    ok: true,
    error: '',
    kid: kid,
    verdict: parts[2],
    score: parts[3] === 'na' ? null : deps.toNumber(parts[3]),
    iat: deps.toNumber(iat),
    exp: deps.toNumber(exp),
    bind: parts[6],
    reasons: parts[7] === '0' ? [] : parts[7].split('-'),
    jti: parts[8]
  };
};

// ---------------------------------------------------------------------------
// request binding
// ---------------------------------------------------------------------------

// Coarse IP: first three IPv4 octets / first four IPv6 hextets. Fine enough to make a
// harvested cookie useless to a botnet on other networks, coarse enough to survive the
// NAT and carrier churn a real visitor sees inside a 30-minute window.
var tsvIpPrefix = function (ip) {
  if (typeof ip !== 'string' || ip.length === 0) return '';
  if (ip.indexOf(':') !== -1) return ip.split(':').slice(0, 4).join(':');
  var octets = ip.split('.');
  if (octets.length !== 4) return ip;
  return octets.slice(0, 3).join('.');
};

// The raw IP is never stored in the cookie — only this truncated salted digest.
var tsvBind = function (deps, salt, ip, userAgent) {
  var ua = typeof userAgent === 'string' ? userAgent : '';
  return deps
    .sha256hex(salt + '|' + tsvIpPrefix(ip) + '|' + ua)
    .substring(0, 8);
};

// ---------------------------------------------------------------------------
// recovering Cloudflare's raw verdict
// ---------------------------------------------------------------------------

// Cloudflare's siteverify `success` flag, recovered from the reason codes.
//
// The raw boolean is not stored -- it does not need to be, because the reason codes
// already distinguish every case, provided they stay split. `nt` (we never got an
// answer) must stay separate from `ie` (Cloudflare answered and said no), and `nh` (the
// browser sent no token) from `mr` (Cloudflare saw no token). Merge either pair and this
// function silently starts lying. The producing side is tsvScore() in scoring.js.
//
// Returns true, false, or undefined -- undefined meaning siteverify was never
// successfully consulted, which is NOT the same as a rejection.
var TSV_CF_FALSE = ['mr', 'ie', 'cfg', 'fg', 'rp'];
var TSV_CF_UNASKED = ['nh', 'sb', 'to', 'er', 'nt', 'bm', 'nk'];

var tsvCfSuccess = function (reasons) {
  if (!reasons) return undefined;
  var i;
  for (i = 0; i < reasons.length; i++) {
    if (TSV_CF_FALSE.indexOf(reasons[i]) !== -1) return false;
  }
  for (i = 0; i < reasons.length; i++) {
    if (TSV_CF_UNASKED.indexOf(reasons[i]) !== -1) return undefined;
  }
  // Everything that remains -- no reasons at all, or only st / am / hm -- describes a
  // token Cloudflare accepted.
  return true;
};

// ---------------------------------------------------------------------------
// score bucket
// ---------------------------------------------------------------------------

// GA4 custom dimensions blow up on high-cardinality values; send the bucket, keep the
// raw score for BigQuery.
var tsvBucket = function (score) {
  if (score === null || score === undefined) return 'none';
  if (score < 20) return '0-19';
  if (score < 40) return '20-39';
  if (score < 60) return '40-59';
  if (score < 80) return '60-79';
  return '80-100';
};
// <<< GENERATED src/shared/verdict-codec.js

// >>> GENERATED src/shared/scoring.js
// Turnstile verdict scoring — CANONICAL SOURCE.
//
// Inlined verbatim into turnstile-verify-client.tpl by build/generate-tpl.js.
// Same sandboxed-JavaScript subset rules as verdict-codec.js (no new/this/Date/Math/
// RegExp/try-catch). See that file's header.
//
// `score` is confidence that this hit came from a verified human, 0-100 — deliberately
// NOT a bot probability. The direction matters: it keeps the design from ever treating
// absence of evidence as evidence of bots.
//
//   human   the challenge was solved, on our hostname, recently
//   suspect solved, but something about the context is off
//   bot     positive evidence of forgery or an off-site token
//   unknown the signal never arrived (ad blocker, no JS, bot that skipped the beacon)
//   error   WE are broken (misconfigured secret, siteverify down)
//
// unknown and error carry score === null, never 0. Collapsing them into a low score is
// what turns this into a machine for mislabelling privacy-conscious humans.

var TSV_VERDICT_HUMAN = 'h';
var TSV_VERDICT_SUSPECT = 's';
var TSV_VERDICT_BOT = 'b';
var TSV_VERDICT_UNKNOWN = 'u';
var TSV_VERDICT_ERROR = 'e';

// Reason codes, kept short so a handful of them still fit one cookie segment.
//
//   am  action mismatch            hm  hostname not allowed
//   st  stale challenge            rp  replay (token reused)
//   fg  forged / invalid token     mr  Cloudflare saw no token in the request
//   nh  the browser sent no token  sb  challenge script blocked
//   to  challenge timed out        er  client-side Turnstile error
//   cfg our Turnstile config is wrong (bad secret / bad request)
//   ie  Cloudflare returned internal-error
//   nt  siteverify unreachable -- we never got an answer
//   bm  verdict cookie failed verification (added by the variable, not here)
//
// `nt` vs `ie` and `nh` vs `mr` are split deliberately: collapsing each pair would make
// it impossible to tell "Cloudflare rejected this" from "we never managed to ask".
// tsvCfSuccess() in verdict-codec.js reads these codes to recover the raw siteverify
// `success` value, so the two lists must stay in step.

// Days-from-civil (Howard Hinnant's algorithm). The sandbox has no Date, so parsing
// Turnstile's `challenge_ts` into unix seconds has to be done by hand. Integer division
// is spelled (a - a % b) / b because Math.floor is unavailable.
var tsvDaysFromCivil = function (y, m, d) {
  var yy = m <= 2 ? y - 1 : y;
  var era = (yy >= 0 ? yy : yy - 399);
  era = (era - (era % 400)) / 400;
  var yoe = yy - era * 400;
  var mp = (m + 9) % 12;
  var doy = (153 * mp + 2);
  doy = (doy - (doy % 5)) / 5 + d - 1;
  var q1 = (yoe - (yoe % 4)) / 4;
  var q100 = (yoe - (yoe % 100)) / 100;
  var doe = yoe * 365 + q1 - q100 + doy;
  return era * 146097 + doe - 719468;
};

// Accepts "2026-09-15T18:53:00Z" / "...T18:53:00.000Z". Returns unix seconds, or null
// if the shape is not exactly what Turnstile documents — we never guess at a timestamp.
var tsvParseIso = function (s, toNumber) {
  if (typeof s !== 'string' || s.length < 20) return null;
  if (s.charAt(4) !== '-' || s.charAt(7) !== '-' || s.charAt(10) !== 'T') return null;
  if (s.charAt(13) !== ':' || s.charAt(16) !== ':') return null;

  var digits = '0123456789';
  var idx = [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18];
  for (var i = 0; i < idx.length; i++) {
    if (digits.indexOf(s.charAt(idx[i])) === -1) return null;
  }

  var y = toNumber(s.substring(0, 4));
  var mo = toNumber(s.substring(5, 7));
  var d = toNumber(s.substring(8, 10));
  var h = toNumber(s.substring(11, 13));
  var mi = toNumber(s.substring(14, 16));
  var sec = toNumber(s.substring(17, 19));
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || sec > 60) return null;

  return tsvDaysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + sec;
};

var tsvHasCode = function (codes, code) {
  if (!codes) return false;
  for (var i = 0; i < codes.length; i++) {
    if (codes[i] === code) return true;
  }
  return false;
};

// input: {
//   tokenPresent, clientReason ('' | 'sb' | 'to' | 'er'),
//   transport ('ok' | 'failed'),          // siteverify HTTP call
//   body,                                 // parsed siteverify JSON, or null
//   expectedAction ('' = accept any), allowedHostnames [lowercased], maxAgeSec, nowSec
// }
// deps: { toNumber }
// returns { verdict, score, reasons[], hostname, action, challengeAge }
var tsvScore = function (deps, input) {
  var reasons = [];
  var out = {
    verdict: TSV_VERDICT_UNKNOWN,
    score: null,
    reasons: reasons,
    hostname: '',
    action: '',
    challengeAge: null
  };

  // The browser told us it could not produce a token. That is a measured population
  // with a cause, not a bot — the whole point of the client sending the hit anyway.
  if (!input.tokenPresent) {
    reasons.push(input.clientReason ? input.clientReason : 'nh');
    return out;
  }

  // siteverify unreachable or timed out: our problem, not the visitor's.
  if (input.transport !== 'ok' || !input.body) {
    out.verdict = TSV_VERDICT_ERROR;
    reasons.push('nt');
    return out;
  }

  var body = input.body;
  var codes = body['error-codes'];

  if (body.success !== true) {
    // Our own misconfiguration. Surfaced as `error` and worth alerting on — if the
    // secret key is wrong, 100% of traffic scores identically and the data is worthless.
    if (
      tsvHasCode(codes, 'missing-input-secret') ||
      tsvHasCode(codes, 'invalid-input-secret') ||
      tsvHasCode(codes, 'bad-request')
    ) {
      out.verdict = TSV_VERDICT_ERROR;
      reasons.push('cfg');
      return out;
    }
    if (tsvHasCode(codes, 'internal-error')) {
      out.verdict = TSV_VERDICT_ERROR;
      reasons.push('ie');
      return out;
    }
    // Token reused or older than 300s. Suspect rather than bot: a double-fired tag or a
    // bfcache restore produces this too, and the client sends idempotency_key to keep a
    // network retry from landing here.
    if (tsvHasCode(codes, 'timeout-or-duplicate')) {
      out.verdict = TSV_VERDICT_SUSPECT;
      out.score = 30;
      reasons.push('rp');
      return out;
    }
    if (tsvHasCode(codes, 'invalid-input-response')) {
      out.verdict = TSV_VERDICT_BOT;
      out.score = 10;
      reasons.push('fg');
      return out;
    }
    if (tsvHasCode(codes, 'missing-input-response')) {
      reasons.push('mr');
      return out;
    }
    // An error code we do not recognise. Cloudflare did answer, and did say no.
    out.verdict = TSV_VERDICT_ERROR;
    reasons.push('ie');
    return out;
  }

  out.hostname = typeof body.hostname === 'string' ? body.hostname : '';
  out.action = typeof body.action === 'string' ? body.action : '';

  // The sitekey is public: anyone can embed it on their own page and mint tokens that
  // verify. `success: true` alone is close to meaningless — this is the real assertion.
  var hostOk = false;
  var host = out.hostname.toLowerCase();
  for (var i = 0; i < input.allowedHostnames.length; i++) {
    if (input.allowedHostnames[i] === host) {
      hostOk = true;
      break;
    }
  }
  if (!hostOk) {
    out.verdict = TSV_VERDICT_BOT;
    out.score = 25;
    reasons.push('hm');
    return out;
  }

  var score = 95;

  var ts = tsvParseIso(body.challenge_ts, deps.toNumber);
  if (ts !== null) {
    var age = input.nowSec - ts;
    if (age < 0) age = 0;
    out.challengeAge = age;
    if (age > input.maxAgeSec) {
      score = 85;
      reasons.push('st');
    } else if (age > 60) {
      score = 90;
    }
  }

  if (input.expectedAction && out.action !== input.expectedAction) {
    // Solved, and on our hostname, but not on the surface we expected.
    out.verdict = TSV_VERDICT_SUSPECT;
    out.score = score < 60 ? score : 60;
    reasons.push('am');
    return out;
  }

  out.verdict = TSV_VERDICT_HUMAN;
  out.score = score;
  return out;
};
// <<< GENERATED src/shared/scoring.js

// >>> GENERATED-STRING src/bootstrap/tsv.js
const TSV_BOOTSTRAP = "/* Turnstile bot-signal bootstrap — CANONICAL SOURCE.\n *\n * Served first-party by the sGTM client at <endpoint>/tsv.js and inlined into\n * turnstile-verify-client.tpl by build/generate-tpl.js. Do not edit the copy in the\n * .tpl — edit here and run `npm run build`.\n *\n * Why this file exists at all: GTM's access_globals permission refuses any path whose\n * first token is a predefined browser global, which rules out both `document.*` and\n * `navigator.sendBeacon`. A web template therefore cannot create the widget container\n * or beacon the token. This runs as ordinary page JavaScript instead, with the web\n * template reduced to writing config and injecting this script.\n *\n * Config arrives as window.tsvq, an array the tag pushes into:\n *   { endpoint, sitekey, action, cdata, absenceTimeout, refreshBefore,\n *     container, stateCookie, debug }\n */\n(function () {\n  'use strict';\n\n  var W = window;\n  var D = document;\n  var API = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=__tsvReady';\n  var READY = '__tsvReady';\n  var STATE = '__tsvState';\n\n  if (W[STATE]) return; // already bootstrapped on this page\n  W[STATE] = { sent: false, started: false };\n\n  var cfg = null;\n  var log = function () {};\n\n  function drainQueue() {\n    var q = W.tsvq;\n    if (!q || !q.length) return null;\n    return q[q.length - 1]; // last write wins; the tag only ever pushes one config\n  }\n\n  function clean(s, max) {\n    if (typeof s !== 'string') return '';\n    var out = '';\n    for (var i = 0; i < s.length && out.length < max; i++) {\n      var c = s.charAt(i);\n      if ('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'.indexOf(c) !== -1) {\n        out += c;\n      }\n    }\n    return out;\n  }\n\n  function readCookie(name) {\n    var all = D.cookie ? D.cookie.split('; ') : [];\n    for (var i = 0; i < all.length; i++) {\n      if (all[i].indexOf(name + '=') === 0) return all[i].substring(name.length + 1);\n    }\n    return '';\n  }\n\n  /* ---- transport ------------------------------------------------------- */\n\n  /* One hit per page, always sent — including when we failed to get a token. An\n   * absent verification hit and a blocked challenge are indistinguishable at the\n   * server otherwise, and \"unknown with a cause\" is a far more useful population\n   * than a hole in the data. */\n  function send(token, reason) {\n    if (W[STATE].sent) return;\n    W[STATE].sent = true;\n\n    var body =\n      'v=1&t=' + encodeURIComponent(token || 'none') +\n      '&a=' + encodeURIComponent(cfg.action) +\n      '&r=' + encodeURIComponent(reason || '');\n    log('send', reason || 'token', body.length);\n\n    // A string body is text/plain, which keeps this a CORS-simple request: no\n    // preflight, credentials included, and Set-Cookie on the response is honoured.\n    if (W.navigator && typeof W.navigator.sendBeacon === 'function') {\n      if (W.navigator.sendBeacon(cfg.endpoint, body)) return;\n    }\n    if (typeof W.fetch === 'function') {\n      W.fetch(cfg.endpoint, {\n        method: 'POST',\n        body: body,\n        keepalive: true,\n        mode: 'no-cors',\n        credentials: 'include'\n      })['catch'](function () {});\n      return;\n    }\n    // Last resort. The token ends up in access logs here, hence the ordering.\n    var img = new Image();\n    img.src = cfg.endpoint + (cfg.endpoint.indexOf('?') === -1 ? '?' : '&') + body +\n      '&cb=' + String(Math.random()).substring(2);\n  }\n\n  /* ---- widget ---------------------------------------------------------- */\n\n  function container() {\n    if (cfg.container) {\n      var found = D.querySelector(cfg.container);\n      if (found) return found;\n      log('configured container not found, creating one');\n    }\n    var el = D.createElement('div');\n    el.id = 'tsv-widget';\n    /* Deliberately NOT display:none. With appearance:'interaction-only' Turnstile\n     * renders nothing until it decides a human must click something; inside a hidden\n     * container that human can never complete it, times out, and gets scored as\n     * suspicious. Zero-footprint but renderable. */\n    el.style.cssText =\n      'position:fixed;right:0;bottom:0;width:0;height:0;overflow:visible;z-index:2147483647';\n    D.body.appendChild(el);\n    return el;\n  }\n\n  function challenge() {\n    var el = container();\n    var id;\n    var params = {\n      sitekey: cfg.sitekey,\n      action: cfg.action,\n      execution: 'execute',\n      appearance: 'interaction-only',\n      size: 'flexible',\n      retry: 'never',\n      callback: function (token) {\n        log('token received');\n        send(token, '');\n        W.turnstile.remove(id);\n      },\n      'error-callback': function (code) {\n        log('error-callback', code);\n        send('', 'er');\n        return true; // we handled it; do not let Turnstile surface an error widget\n      },\n      'timeout-callback': function () {\n        log('timeout-callback');\n        send('', 'to');\n      }\n    };\n    if (cfg.cdata) params.cdata = cfg.cdata;\n\n    id = W.turnstile.render(el, params);\n    W.turnstile.execute(id);\n  }\n\n  function loadApi() {\n    /* Already on the page, loaded by something else. render() being a function means\n     * the API is initialised, so there is nothing to wait for. */\n    if (W.turnstile && typeof W.turnstile.render === 'function') {\n      challenge();\n      return;\n    }\n\n    /* The onload query parameter is Turnstile's documented hook for asynchronous\n     * loading, and the only correct one here: turnstile.ready() throws outright\n     * (\"Remove async/defer from the Turnstile api.js script tag before using\n     * turnstile.ready()\") when the script tag carries async or defer, which this one\n     * must, since it is injected. */\n    W[READY] = function () {\n      challenge();\n    };\n\n    var s = D.createElement('script');\n    s.src = API;\n    s.async = true;\n    s.defer = true;\n    /* Blocked by an ad blocker, a CSP that omits challenges.cloudflare.com, or a\n     * network failure. Reported as its own reason code so the resulting `unknown`\n     * is attributable rather than mysterious. */\n    s.onerror = function () {\n      log('api.js blocked');\n      send('', 'sb');\n    };\n    D.head.appendChild(s);\n  }\n\n  /* ---- entry ----------------------------------------------------------- */\n\n  function start() {\n    if (W[STATE].started) return;\n    W[STATE].started = true;\n\n    /* A live verdict cookie is still good, so do not burn a challenge. _tsv_st holds\n     * only the expiry, which is why the verdict cookie itself can stay HttpOnly. */\n    var st = readCookie(cfg.stateCookie);\n    if (st && /^[0-9]{1,12}$/.test(st)) {\n      var remaining = parseInt(st, 10) - Math.floor(Date.now() / 1000);\n      if (remaining > cfg.refreshBefore) {\n        log('verdict still valid for', remaining, 's — skipping');\n        return;\n      }\n    }\n\n    /* Nothing may be sent before the absence timer is armed: without it a blocked\n     * api.js produces no hit at all and the visitor silently vanishes from the data. */\n    W.setTimeout(function () {\n      send('', 'to');\n    }, cfg.absenceTimeout);\n\n    loadApi();\n  }\n\n  function boot() {\n    var raw = drainQueue();\n    if (!raw || !raw.endpoint || !raw.sitekey) return;\n\n    cfg = {\n      endpoint: raw.endpoint,\n      sitekey: raw.sitekey,\n      action: clean(raw.action, 32) || 'page_view',\n      cdata: clean(raw.cdata, 255),\n      absenceTimeout: raw.absenceTimeout > 0 ? raw.absenceTimeout : 4000,\n      refreshBefore: raw.refreshBefore > 0 ? raw.refreshBefore : 300,\n      container: typeof raw.container === 'string' ? raw.container : '',\n      stateCookie: raw.stateCookie || '_tsv_st',\n      debug: !!raw.debug\n    };\n    if (cfg.debug && W.console) {\n      log = function () {\n        var a = ['[tsv]'];\n        for (var i = 0; i < arguments.length; i++) a.push(arguments[i]);\n        W.console.log.apply(W.console, a);\n      };\n    }\n\n    /* Speculation-rules prerenders run this script in pages the user may never visit.\n     * Minting a token there spends a single-use credential on a phantom session and is\n     * a common source of mystery timeout-or-duplicate floods. */\n    if (D.prerendering) {\n      D.addEventListener('prerenderingchange', start, { once: true });\n      return;\n    }\n    if (D.body) start();\n    else D.addEventListener('DOMContentLoaded', start, { once: true });\n  }\n\n  boot();\n})();\n";
// <<< GENERATED-STRING src/bootstrap/tsv.js

const log = function () {
  if (data.debugLogging) logToConsole('[turnstile-verify]', arguments[0], arguments[1]);
};

const deps = {
  sha256hex: function (s) {
    return sha256Sync(s, { outputEncoding: 'hex' });
  },
  toNumber: function (s) {
    return makeNumber(s);
  },
  nonce: function () {
    return makeString(generateRandom(0, 2147483647)) + '|' + makeString(getTimestampMillis());
  }
};

const nowSec = makeInteger(getTimestampMillis() / 1000);

const normPath = function (p) {
  let out = makeString(p);
  if (out.indexOf('/') !== 0) out = '/' + out;
  while (out.length > 1 && out.substring(out.length - 1) === '/') {
    out = out.substring(0, out.length - 1);
  }
  return out;
};

const verifyPath = normPath(data.claimPath);
const scriptPath = verifyPath + '.js';
const path = getRequestPath();
const method = getRequestMethod();

// --------------------------------------------------------------------------
// parameter parsing
// --------------------------------------------------------------------------

const parseForm = function (raw, out) {
  if (!raw) return out;
  const pairs = makeString(raw).split('&');
  for (let i = 0; i < pairs.length; i++) {
    const eq = pairs[i].indexOf('=');
    if (eq <= 0) continue;
    const k = pairs[i].substring(0, eq);
    const v = decodeUriComponent(pairs[i].substring(eq + 1));
    if (k === 't' || k === 'a' || k === 'r' || k === 'v') out[k] = v ? v : '';
  }
  return out;
};

const readParams = function () {
  const out = { v: '', t: '', a: '', r: '' };
  if (method === 'POST') return parseForm(getRequestBody(), out);
  // The GET form is the bootstrap's last-resort transport, where the token rides in
  // the query string and therefore lands in access logs.
  const q = getRequestQueryParameters();
  if (q) {
    out.v = q.v ? makeString(q.v) : '';
    out.t = q.t ? makeString(q.t) : '';
    out.a = q.a ? makeString(q.a) : '';
    out.r = q.r ? makeString(q.r) : '';
  }
  return out;
};

// Only the three codes the bootstrap can legitimately report. Anything else the client
// makes up is discarded rather than written into a signed cookie.
const cleanReason = function (r) {
  return r === 'sb' || r === 'to' || r === 'er' ? r : '';
};

// Turnstile wants a UUID here. Deriving it from the token means a network-level retry
// of the same verification returns the original result instead of `timeout-or-duplicate`
// — which would otherwise show up as a bogus replay verdict for a real person.
const idempotencyKey = function (token) {
  const h = sha256Sync('idem|' + token, { outputEncoding: 'hex' });
  return h.substring(0, 8) + '-' + h.substring(8, 12) + '-4' + h.substring(13, 16) +
    '-a' + h.substring(17, 20) + '-' + h.substring(20, 32);
};

// --------------------------------------------------------------------------
// response
// --------------------------------------------------------------------------

const respond = function (result, jti) {
  const cfSuccess = tsvCfSuccess(result.reasons);
  const cookieTtl = makeInteger(makeNumber(data.cookieTtl));
  const exp = nowSec + cookieTtl;

  const bind = data.bindEnabled
    ? tsvBind(deps, data.bindSalt, getRemoteAddress(), getRequestHeader('user-agent'))
    : '0';

  const cookieValue = tsvEncode(deps, {
    kid: data.keyId,
    secret: data.macSecret,
    verdict: result.verdict,
    score: result.score,
    iat: nowSec,
    exp: exp,
    bind: bind,
    reasons: result.reasons,
    jti: jti
  });

  if (cookieValue) {
    // noEncode: the cookie charset is deliberately URL-safe, and encoding it would
    // change the bytes the variable has to verify.
    setCookie(data.cookieName, cookieValue, {
      domain: data.cookieDomain,
      path: '/',
      'max-age': cookieTtl,
      secure: true,
      httpOnly: true,
      sameSite: 'Lax'
    }, true);

    setCookie(data.stateCookieName, makeString(exp), {
      domain: data.cookieDomain,
      path: '/',
      'max-age': cookieTtl,
      secure: true,
      httpOnly: false,
      sameSite: 'Lax'
    }, true);
  } else {
    log('cookie encoding refused a malformed field; no cookie set', result.verdict);
  }

  setResponseHeader('cache-control', 'no-store');
  if (data.debugResponse) {
    setResponseStatus(200);
    setResponseHeader('content-type', 'application/json');
    setResponseBody(JSON.stringify({
      verdict: result.verdict,
      // Explicit null rather than undefined: JSON.stringify drops undefined keys, and a
      // debug endpoint that silently omits a field is worse than useless.
      cf_success: cfSuccess === undefined ? null : cfSuccess,
      score: result.score,
      bucket: tsvBucket(result.score),
      reasons: result.reasons,
      hostname: result.hostname,
      action: result.action,
      challenge_age: result.challengeAge,
      exp: exp,
      cookie_set: cookieValue ? true : false
    }));
  } else {
    setResponseStatus(204);
  }

  log('verdict', result.verdict + ' ' + makeString(result.score) + ' ' + result.reasons.join('-'));

  if (data.emitEvent) {
    runContainer({
      event_name: data.eventName,
      tsv_verdict: result.verdict,
      tsv_cf_success: cfSuccess,
      tsv_score: result.score,
      tsv_reasons: result.reasons.join('-'),
      tsv_hostname: result.hostname,
      tsv_action: result.action,
      tsv_challenge_age: result.challengeAge,
      tsv_exp: exp
    }, function () {
      returnResponse();
    });
  } else {
    returnResponse();
  }
};

// --------------------------------------------------------------------------
// verification
// --------------------------------------------------------------------------

const hostnames = [];
if (data.allowedHostnames) {
  for (let i = 0; i < data.allowedHostnames.length; i++) {
    const h = data.allowedHostnames[i].hostname;
    if (h) hostnames.push(makeString(h).toLowerCase());
  }
}

const scoreInput = function (transport, body, tokenPresent, clientReason) {
  return {
    tokenPresent: tokenPresent,
    clientReason: clientReason,
    transport: transport,
    body: body,
    expectedAction: data.expectedAction ? makeString(data.expectedAction) : '',
    allowedHostnames: hostnames,
    maxAgeSec: makeNumber(data.maxChallengeAge),
    nowSec: nowSec
  };
};

const verify = function () {
  const params = readParams();
  const token = params.t;
  const reason = cleanReason(params.r);
  const tokenPresent = token && token !== 'none' && token.length > 20 && token.length <= 2048;

  if (!tokenPresent) {
    // The bootstrap sends this hit even when it could not get a token, which is what
    // makes "no signal" a measurable population with a cause instead of a silent hole.
    log('no token', reason || 'nh');
    respond(tsvScore(deps, scoreInput('ok', null, false, reason)), 'none');
    return;
  }

  const jti = sha256Sync(token, { outputEncoding: 'hex' }).substring(0, 8);

  let body = 'secret=' + encodeUriComponent(data.secretKey) +
    '&response=' + encodeUriComponent(token) +
    '&idempotency_key=' + idempotencyKey(token);
  if (data.sendRemoteIp) {
    const ip = getRemoteAddress();
    if (ip) body = body + '&remoteip=' + encodeUriComponent(ip);
  }

  sendHttpRequest(SITEVERIFY, {
    method: 'POST',
    timeout: makeInteger(makeNumber(data.siteverifyTimeout)),
    headers: { 'content-type': 'application/x-www-form-urlencoded' }
  }, body).then(function (res) {
    let parsed = null;
    if (res && res.statusCode >= 200 && res.statusCode < 300 && res.body) {
      // The sandbox's JSON.parse returns undefined rather than throwing, so a garbled
      // body degrades to `error` instead of taking the client down.
      const p = JSON.parse(res.body);
      if (p) parsed = p;
    }
    if (!parsed) log('siteverify unusable response', res ? res.statusCode : 'none');
    respond(tsvScore(deps, scoreInput(parsed ? 'ok' : 'failed', parsed, true, '')), jti);
  }, function (err) {
    log('siteverify failed', err && err.reason ? err.reason : 'unknown');
    respond(tsvScore(deps, scoreInput('failed', null, true, '')), jti);
  });
};

// --------------------------------------------------------------------------
// routing
// --------------------------------------------------------------------------

// Claim conservatively: exact path, known method. Anything else falls through so this
// client can never shadow the GA4 client or a health check.
if (data.serveBootstrap && path === scriptPath && method === 'GET') {
  claimRequest();
  setResponseStatus(200);
  setResponseHeader('content-type', 'text/javascript; charset=utf-8');
  setResponseHeader('cache-control', 'public, max-age=' + makeString(makeInteger(makeNumber(data.bootstrapCacheSeconds))));
  setResponseBody(TSV_BOOTSTRAP);
  returnResponse();
} else if (path === verifyPath && (method === 'POST' || method === 'GET')) {
  claimRequest();
  verify();
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "headersAllowed",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "user-agent"
                  }
                ]
              }
            ]
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://challenges.cloudflare.com/"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "set_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedCookies",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "name"
                  },
                  {
                    "type": 1,
                    "string": "domain"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "secure"
                  },
                  {
                    "type": 1,
                    "string": "session"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "_tsv"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "name"
                  },
                  {
                    "type": 1,
                    "string": "domain"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "secure"
                  },
                  {
                    "type": 1,
                    "string": "session"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "_tsv_st"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  },
                  {
                    "type": 1,
                    "string": "any"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_response",
        "versionId": "1"
      },
      "param": [
        {
          "key": "writeResponseAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "writeHeaderAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "return_response",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "run_container",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: A solved challenge on an allowed hostname sets a human verdict cookie
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=' + TOKEN + '&a=page_view&r=');
    mockSiteverify({
      success: true,
      'error-codes': [],
      hostname: 'shop.example.com',
      action: 'page_view',
      challenge_ts: nowIso()
    });

    runCode(mockData);

    callLater(() => {
      assertApi('claimRequest').wasCalled();
      assertThat(cookies._tsv, 'verdict cookie').isDefined();
      const parts = cookies._tsv.split('.');
      assertThat(parts.length, 'segment count').isEqualTo(10);
      assertThat(parts[2], 'verdict').isEqualTo('h');
      assertThat(parts[3], 'score').isEqualTo('95');
      assertThat(cookieOpts._tsv.httpOnly, 'verdict cookie must be HttpOnly').isTrue();
      assertThat(cookieOpts._tsv_st.httpOnly, 'state cookie must be readable').isFalse();
      assertApi('setResponseStatus').wasCalledWith(204);
    });
- name: A token minted on another site scores as a bot
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=' + TOKEN + '&a=page_view&r=');
    mockSiteverify({
      success: true,
      'error-codes': [],
      hostname: 'attacker.example.net',
      action: 'page_view',
      challenge_ts: nowIso()
    });

    runCode(mockData);

    callLater(() => {
      const parts = cookies._tsv.split('.');
      assertThat(parts[2], 'verdict').isEqualTo('b');
      assertThat(parts[3], 'score').isEqualTo('25');
      assertThat(parts[7], 'reasons').isEqualTo('hm');
    });
- name: A replayed token is suspect, not bot
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=' + TOKEN + '&a=page_view&r=');
    mockSiteverify({ success: false, 'error-codes': ['timeout-or-duplicate'] });

    runCode(mockData);

    callLater(() => {
      const parts = cookies._tsv.split('.');
      assertThat(parts[2], 'verdict').isEqualTo('s');
      assertThat(parts[7], 'reasons').isEqualTo('rp');
    });
- name: A bad secret key is reported as an error with no score
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=' + TOKEN + '&a=page_view&r=');
    mockSiteverify({ success: false, 'error-codes': ['invalid-input-secret'] });

    runCode(mockData);

    callLater(() => {
      const parts = cookies._tsv.split('.');
      assertThat(parts[2], 'verdict').isEqualTo('e');
      assertThat(parts[3], 'score must be absent, not zero').isEqualTo('na');
      assertThat(parts[7], 'reasons').isEqualTo('cfg');
    });
- name: A blocked challenge script is unknown with a cause, and never calls siteverify
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=none&a=page_view&r=sb');
    let siteverifyCalled = false;
    mock('sendHttpRequest', () => {
      siteverifyCalled = true;
      return Promise.create((resolve) => resolve({ statusCode: 200, body: '{}' }));
    });

    runCode(mockData);

    callLater(() => {
      assertThat(siteverifyCalled, 'must not spend a siteverify call').isFalse();
      const parts = cookies._tsv.split('.');
      assertThat(parts[2], 'verdict').isEqualTo('u');
      assertThat(parts[3], 'score must be absent, not zero').isEqualTo('na');
      assertThat(parts[7], 'reasons').isEqualTo('sb');
    });
- name: Siteverify being unreachable is an error, not a judgement about the visitor
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=' + TOKEN + '&a=page_view&r=');
    mock('sendHttpRequest', () => Promise.create((resolve, reject) => reject({ reason: 'timed_out' })));

    runCode(mockData);

    callLater(() => {
      const parts = cookies._tsv.split('.');
      assertThat(parts[2], 'verdict').isEqualTo('e');
      assertThat(parts[3]).isEqualTo('na');
      assertThat(parts[7], 'reasons').isEqualTo('nt');
    });
- name: A client-supplied reason code that is not ours is discarded
  code: |-
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=none&a=page_view&r=h.95.9999999999');

    runCode(mockData);

    callLater(() => {
      const parts = cookies._tsv.split('.');
      assertThat(parts.length, 'injected delimiters must not shift fields').isEqualTo(10);
      assertThat(parts[2]).isEqualTo('u');
      assertThat(parts[7], 'reasons').isEqualTo('nh');
    });
- name: Serves the bootstrap script on its own path
  code: |-
    mock('getRequestPath', '/tsv.js');
    mock('getRequestMethod', 'GET');

    runCode(mockData);

    assertApi('claimRequest').wasCalled();
    assertApi('setResponseStatus').wasCalledWith(200);
    assertThat(responseBody, 'bootstrap body').contains('challenges.cloudflare.com');
    assertThat(responseHeaders['content-type']).contains('text/javascript');
- name: Unrelated paths are not claimed
  code: |-
    mock('getRequestPath', '/g/collect');
    mock('getRequestMethod', 'POST');
    let claimed = false;
    mock('claimRequest', () => { claimed = true; });

    runCode(mockData);

    assertThat(claimed, 'must not shadow another client').isFalse();
- name: A path with a trailing slash still matches
  code: |-
    mockData.claimPath = 'tsv/';
    mock('getRequestPath', '/tsv');
    mock('getRequestMethod', 'POST');
    mock('getRequestBody', 'v=1&t=none&a=page_view&r=');

    runCode(mockData);

    callLater(() => {
      assertApi('claimRequest').wasCalled();
    });
setup: |-
  const Promise = require('Promise');
  const JSON = require('JSON');

  const TOKEN = '0.abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOP';

  const mockData = {
    claimPath: '/tsv',
    serveBootstrap: true,
    bootstrapCacheSeconds: '3600',
    secretKey: '0x4AAAAAAA_test_secret',
    allowedHostnames: [{ hostname: 'shop.example.com' }],
    expectedAction: 'page_view',
    maxChallengeAge: '120',
    siteverifyTimeout: '1500',
    sendRemoteIp: true,
    macSecret: 'test-signing-key-aaaaaaaaaaaaaaaaaaaa',
    keyId: 'k1',
    cookieName: '_tsv',
    stateCookieName: '_tsv_st',
    cookieTtl: '1800',
    cookieDomain: 'auto',
    bindEnabled: true,
    bindSalt: 'test-salt',
    emitEvent: false,
    eventName: 'turnstile_verification',
    debugResponse: false,
    debugLogging: false
  };

  const cookies = {};
  const cookieOpts = {};
  const responseHeaders = {};
  let responseBody = '';

  mock('setCookie', (name, value, options) => {
    cookies[name] = value;
    cookieOpts[name] = options;
  });
  mock('setResponseHeader', (name, value) => { responseHeaders[name] = value; });
  mock('setResponseBody', (body) => { responseBody = body; });
  mock('getRemoteAddress', () => '203.0.113.42');
  mock('getRequestHeader', () => 'Mozilla/5.0 (test)');

  // The container's own clock, so challenge_ts freshness is deterministic.
  const nowIso = () => '2025-09-15T12:40:00.000Z';
  mock('getTimestampMillis', () => 1757944800000);

  const mockSiteverify = (body) => {
    mock('sendHttpRequest', (url, options, requestBody) => {
      assertThat(url, 'siteverify endpoint').isEqualTo('https://challenges.cloudflare.com/turnstile/v0/siteverify');
      assertThat(requestBody, 'must send an idempotency key').contains('idempotency_key=');
      assertThat(requestBody, 'must send the secret').contains('secret=');
      return Promise.create((resolve) => resolve({ statusCode: 200, body: JSON.stringify(body) }));
    });
  };


___NOTES___

Verifies a Cloudflare Turnstile token and turns it into a signed, first-party verdict
cookie that the "Turnstile Verdict" variable reads on every later hit.

WHAT THIS IS NOT
Turnstile's siteverify API returns pass/fail, not a score. The 0-100 number this client
produces is composed here, from the verdict plus the hostname, action, freshness and
replay checks. It is confidence that a hit came from a verified human -- not a
Cloudflare bot score, and not a security control: a bot that never sends the
verification hit produces no signal at all. Enrich with it; do not gate on it.

THE CHECK THAT MATTERS
The Turnstile site key is public. Anyone can put it on their own page and mint tokens
that verify successfully, so `success: true` alone proves very little. The allowed
hostname list is what the score actually rests on -- keep it accurate.

SETUP
1. Create a Turnstile widget in the Cloudflare dashboard. Add every hostname the widget
   will run on.
2. Configure this client with the secret key, the same hostnames, and a signing key of
   your own invention (any long random string).
3. Add the "Turnstile Verdict" variable to this container with the SAME signing key,
   key ID, cookie name and binding salt.
4. In the web container, add the "Turnstile Bot Signal" tag pointing at
   https://<this server>/tsv, firing on initialisation.
5. Add a built-in "Augment Event" transformation that writes the variable's fields onto
   your events.

The server container must be on the same registrable domain as the website, or the
verdict cookie is a third-party cookie and will be discarded by most browsers.

PRIVACY
- The visitor IP is sent to Cloudflare unless you turn that off.
- The cookie stores a truncated salted hash of the coarse IP and user agent, never the
  raw address.
- This client does not gate on consent. If you rely on Turnstile being "strictly
  necessary", have that reviewed; the enrichment of analytics data is a separate purpose
  from the bot check itself.
