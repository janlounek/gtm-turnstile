___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Turnstile Verdict",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Reads and verifies the signed Turnstile verdict cookie written by the Turnstile Verify client, and exposes the human-confidence score to tags and transformations.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "SELECT",
    "name": "output",
    "displayName": "Output",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "object",
        "displayValue": "All fields (object)"
      },
      {
        "value": "verdict",
        "displayValue": "Verdict (human / suspect / bot / unknown / error)"
      },
      {
        "value": "cf_success",
        "displayValue": "Cloudflare siteverify success (true / false / undefined)"
      },
      {
        "value": "score",
        "displayValue": "Score (0-100, or undefined)"
      },
      {
        "value": "bucket",
        "displayValue": "Score bucket"
      },
      {
        "value": "reasons",
        "displayValue": "Reason codes"
      },
      {
        "value": "source",
        "displayValue": "Source (cookie / none)"
      },
      {
        "value": "age",
        "displayValue": "Verdict age (seconds)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "object",
    "help": "Use <strong>All fields</strong> with an <strong>Augment Event</strong> transformation to write every <code>tsv_*</code> parameter onto your events at once. The single-field outputs are for tags that want just one value."
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
    ],
    "help": "Must match the Turnstile Verify client."
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "keys",
    "displayName": "Signing keys",
    "simpleTableColumns": [
      {
        "defaultValue": "k1",
        "displayName": "Key ID",
        "name": "kid",
        "type": "TEXT",
        "isUnique": true
      },
      {
        "defaultValue": "",
        "displayName": "Signing key",
        "name": "secret",
        "type": "TEXT"
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
    "help": "The key IDs and signing keys this variable will accept. To rotate: add the new key here and publish, then switch the client to the new key ID, then remove the old row once all old cookies have expired."
  },
  {
    "type": "CHECKBOX",
    "name": "bindEnabled",
    "checkboxText": "Check the client binding",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "Must match the client's setting. A mismatch means the cookie is being presented from a different network or browser than it was issued to; the result is <em>unknown</em>, never <em>bot</em>, because real people change networks."
  },
  {
    "type": "TEXT",
    "name": "bindSalt",
    "displayName": "Binding salt",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "bindEnabled",
        "paramValue": true,
        "type": "EQUALS"
      }
    ],
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "Must match the Turnstile Verify client exactly."
  },
  {
    "type": "CHECKBOX",
    "name": "debugLogging",
    "checkboxText": "Log to the console in preview mode",
    "simpleValueType": true,
    "defaultValue": false
  }
]


___SANDBOXED_JS_FOR_SERVER___

const getCookieValues = require('getCookieValues');
const getRequestHeader = require('getRequestHeader');
const getRemoteAddress = require('getRemoteAddress');
const sha256Sync = require('sha256Sync');
const generateRandom = require('generateRandom');
const getTimestampMillis = require('getTimestampMillis');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const makeInteger = require('makeInteger');
const logToConsole = require('logToConsole');

const TEMPLATE_VERSION = 1;

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

// Everything below runs synchronously, and it has to: a server variable cannot await.
// sendHttpRequest, Firestore.read and sha256 all return Promises, so getCookieValues
// plus sha256Sync are the only primitives that can produce a verified verdict here.
// That constraint is why the client signs a cookie out of band rather than this
// variable verifying a token itself.

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

const VERDICT_NAMES = {
  h: 'human',
  s: 'suspect',
  b: 'bot',
  u: 'unknown',
  e: 'error'
};

const nowSec = makeInteger(getTimestampMillis() / 1000);

const log = function (a, b) {
  if (data.debugLogging) logToConsole('[turnstile-verdict]', a, b);
};

const keys = [];
if (data.keys) {
  for (let i = 0; i < data.keys.length; i++) {
    if (data.keys[i].kid && data.keys[i].secret) {
      keys.push({ kid: makeString(data.keys[i].kid), secret: makeString(data.keys[i].secret) });
    }
  }
}

const absent = function (reason) {
  return {
    tsv_verdict: 'unknown',
    tsv_cf_success: undefined,
    tsv_score: undefined,
    tsv_score_bucket: 'none',
    tsv_reasons: reason,
    tsv_source: 'none',
    tsv_age_s: undefined,
    tsv_v: TEMPLATE_VERSION
  };
};

const build = function () {
  if (keys.length === 0) {
    log('no signing keys configured');
    return absent('nk');
  }

  // noDecode: the client wrote the cookie unencoded, and re-encoding would change the
  // bytes the MAC covers.
  const values = getCookieValues(data.cookieName, true);
  if (!values || values.length === 0) return absent('nh');

  const decoded = tsvDecode(deps, { value: values[0], keys: keys, nowSec: nowSec });
  if (!decoded.ok) {
    log('cookie rejected', decoded.error);
    // A forged or corrupt cookie is not evidence of a bot -- a truncating proxy and a
    // rotated key look identical here. It only means we have no verdict.
    return absent(decoded.error === 'expired' ? 'nh' : 'bm');
  }

  if (data.bindEnabled) {
    const expected = tsvBind(deps, data.bindSalt, getRemoteAddress(), getRequestHeader('user-agent'));
    if (decoded.bind !== '0' && decoded.bind !== expected) {
      log('bind mismatch', decoded.bind + ' != ' + expected);
      return absent('bm');
    }
  }

  return {
    tsv_verdict: VERDICT_NAMES[decoded.verdict] ? VERDICT_NAMES[decoded.verdict] : 'unknown',
    // Cloudflare's own pass/fail, recovered from the reason codes. undefined means
    // siteverify was never consulted -- distinct from a rejection.
    tsv_cf_success: tsvCfSuccess(decoded.reasons),
    tsv_score: decoded.score === null ? undefined : decoded.score,
    tsv_score_bucket: tsvBucket(decoded.score),
    tsv_reasons: decoded.reasons.length === 0 ? '' : decoded.reasons.join('-'),
    tsv_source: 'cookie',
    tsv_age_s: nowSec - decoded.iat,
    tsv_v: TEMPLATE_VERSION
  };
};

const result = build();

if (data.output === 'verdict') return result.tsv_verdict;
if (data.output === 'cf_success') return result.tsv_cf_success;
if (data.output === 'score') return result.tsv_score;
if (data.output === 'bucket') return result.tsv_score_bucket;
if (data.output === 'reasons') return result.tsv_reasons;
if (data.output === 'source') return result.tsv_source;
if (data.output === 'age') return result.tsv_age_s;
return result;


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "_tsv"
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
- name: A valid cookie yields the full field set
  code: |-
    setCookie(signed('h', '95', NOW, NOW + 1800, BIND, '0'));

    const r = runCode(mockData);

    assertThat(r.tsv_verdict).isEqualTo('human');
    assertThat(r.tsv_score).isEqualTo(95);
    assertThat(r.tsv_score_bucket).isEqualTo('80-100');
    assertThat(r.tsv_reasons).isEqualTo('');
    assertThat(r.tsv_source).isEqualTo('cookie');
    assertThat(r.tsv_age_s).isEqualTo(0);
- name: Single-field outputs return scalars
  code: |-
    setCookie(signed('s', '60', NOW - 30, NOW + 1800, BIND, 'am'));

    mockData.output = 'verdict';
    assertThat(runCode(mockData)).isEqualTo('suspect');

    mockData.output = 'score';
    assertThat(runCode(mockData)).isEqualTo(60);

    mockData.output = 'bucket';
    assertThat(runCode(mockData)).isEqualTo('60-79');

    mockData.output = 'reasons';
    assertThat(runCode(mockData)).isEqualTo('am');

    mockData.output = 'age';
    assertThat(runCode(mockData)).isEqualTo(30);
- name: An absent score stays undefined rather than collapsing to zero
  code: |-
    setCookie(signed('u', 'na', NOW, NOW + 1800, BIND, 'sb'));

    const r = runCode(mockData);

    assertThat(r.tsv_verdict).isEqualTo('unknown');
    assertThat(r.tsv_score).isUndefined();
    assertThat(r.tsv_score_bucket).isEqualTo('none');
    assertThat(r.tsv_reasons).isEqualTo('sb');
- name: Cloudflare's own pass/fail is recoverable on every hit
  code: |-
    setCookie(signed('h', '95', NOW, NOW + 1800, BIND, '0'));
    assertThat(runCode(mockData).tsv_cf_success, 'solved').isTrue();

    setCookie(signed('b', '25', NOW, NOW + 1800, BIND, 'hm'));
    assertThat(runCode(mockData).tsv_cf_success, 'off-site token still verified').isTrue();

    setCookie(signed('b', '10', NOW, NOW + 1800, BIND, 'fg'));
    assertThat(runCode(mockData).tsv_cf_success, 'forged token').isFalse();

    setCookie(signed('e', 'na', NOW, NOW + 1800, BIND, 'ie'));
    assertThat(runCode(mockData).tsv_cf_success, 'Cloudflare answered no').isFalse();

    // The distinction the split reason codes exist for: never asked is not a rejection.
    setCookie(signed('e', 'na', NOW, NOW + 1800, BIND, 'nt'));
    assertThat(runCode(mockData).tsv_cf_success, 'siteverify unreachable').isUndefined();

    setCookie(signed('u', 'na', NOW, NOW + 1800, BIND, 'sb'));
    assertThat(runCode(mockData).tsv_cf_success, 'challenge blocked').isUndefined();

    mockData.output = 'cf_success';
    setCookie(signed('h', '95', NOW, NOW + 1800, BIND, '0'));
    assertThat(runCode(mockData)).isTrue();
- name: No cookie at all is unknown, not bot
  code: |-
    mock('getCookieValues', () => []);

    const r = runCode(mockData);

    assertThat(r.tsv_verdict).isEqualTo('unknown');
    assertThat(r.tsv_source).isEqualTo('none');
    assertThat(r.tsv_reasons).isEqualTo('nh');
    assertThat(r.tsv_score).isUndefined();
    assertThat(r.tsv_cf_success, 'no cookie is not a rejection').isUndefined();
- name: A tampered verdict is refused
  code: |-
    const good = signed('b', '10', NOW, NOW + 1800, BIND, 'fg');
    const parts = good.split('.');
    parts[2] = 'h';
    parts[3] = '95';
    setCookie(parts.join('.'));

    const r = runCode(mockData);

    assertThat(r.tsv_verdict, 'a forged cookie must never read back as human').isEqualTo('unknown');
    assertThat(r.tsv_source).isEqualTo('none');
- name: An unknown key ID is refused
  code: |-
    setCookie(signed('h', '95', NOW, NOW + 1800, BIND, '0'));
    mockData.keys = [{ kid: 'k9', secret: 'some-other-key' }];

    const r = runCode(mockData);

    assertThat(r.tsv_verdict).isEqualTo('unknown');
- name: Key rotation accepts both the old and the new key
  code: |-
    setCookie(signed('h', '95', NOW, NOW + 1800, BIND, '0'));
    mockData.keys = [
      { kid: 'k0', secret: 'retired-key' },
      { kid: 'k1', secret: SECRET }
    ];

    assertThat(runCode(mockData).tsv_verdict).isEqualTo('human');
- name: An expired cookie is unknown, not bot
  code: |-
    setCookie(signed('h', '95', NOW - 3600, NOW - 1800, BIND, '0'));

    const r = runCode(mockData);

    assertThat(r.tsv_verdict).isEqualTo('unknown');
    assertThat(r.tsv_reasons).isEqualTo('nh');
- name: A cookie presented from another network is unknown, never bot
  code: |-
    setCookie(signed('h', '95', NOW, NOW + 1800, 'deadbeef', '0'));

    const r = runCode(mockData);

    assertThat(r.tsv_verdict, 'a network change must not look like fraud').isEqualTo('unknown');
    assertThat(r.tsv_reasons).isEqualTo('bm');
- name: Garbage in the cookie never throws
  code: |-
    const junk = ['', 'x', 'a.b.c', '....', '1.k1.h.95.x.x.x.x.x.x'];
    for (let i = 0; i < junk.length; i++) {
      setCookie(junk[i]);
      assertThat(runCode(mockData).tsv_verdict).isEqualTo('unknown');
    }
setup: |-
  const sha256Sync = require('sha256Sync');

  const NOW = 1757944800;
  const SECRET = 'test-signing-key-aaaaaaaaaaaaaaaaaaaa';
  const SALT = 'test-salt';

  mock('getTimestampMillis', () => NOW * 1000);
  mock('getRemoteAddress', () => '203.0.113.42');
  mock('getRequestHeader', () => 'Mozilla/5.0 (test)');

  const hex = (s) => sha256Sync(s, { outputEncoding: 'hex' });
  const pad10 = (n) => {
    let s = '' + n;
    while (s.length < 10) s = '0' + s;
    return s;
  };

  // Deliberately a second, independent implementation of the MAC. If the generated
  // codec in the template ever drifts from the specification, these tests fail here
  // rather than silently turning every visitor into `unknown` in production.
  const mac = (kid, payload) => {
    const inner = hex(SECRET + '|tsvc1|' + kid + '|' + payload);
    return hex(SECRET + '|' + inner).substring(0, 32);
  };

  const signed = (verdict, score, iat, exp, bind, reasons) => {
    const payload = ['1', 'k1', verdict, score, pad10(iat), pad10(exp), bind, reasons, 'abc12345'].join('.');
    return payload + '.' + mac('k1', payload);
  };

  const BIND = hex(SALT + '|203.0.113|Mozilla/5.0 (test)').substring(0, 8);

  const setCookie = (value) => mock('getCookieValues', () => [value]);

  const mockData = {
    output: 'object',
    cookieName: '_tsv',
    keys: [{ kid: 'k1', secret: SECRET }],
    bindEnabled: true,
    bindSalt: SALT,
    debugLogging: false
  };


___NOTES___

Reads the signed verdict cookie written by the "Turnstile Verify" client and exposes it
to tags, triggers and transformations. Configure it with the SAME signing key, key ID,
cookie name and binding salt as the client, or every cookie fails verification and every
visitor reads back as `unknown`.

FIELDS (with Output set to "All fields")
  tsv_verdict       human | suspect | bot | unknown | error
  tsv_cf_success    Cloudflare's raw siteverify success: true | false | undefined
  tsv_score         0-100, or undefined
  tsv_score_bucket  0-19 | 20-39 | 40-59 | 60-79 | 80-100 | none
  tsv_reasons       '-'-joined codes: am hm st rp fg mr nh sb to er cfg ie nt bm nk
  tsv_source        cookie | none
  tsv_age_s         seconds since the verdict was issued
  tsv_v             template version

READING THE OUTPUT
`unknown` is not a quiet `bot`. It means no usable signal arrived -- an ad blocker, a
browser with no JavaScript, a rotated key, or a bot that simply skipped the verification
hit. `error` means this setup is broken (wrong secret, Cloudflare unreachable) and is
worth alerting on. Neither carries a score, which is why tsv_score is undefined rather
than 0 for both.

tsv_cf_success is Cloudflare's own pass/fail, recovered from the reason codes. Note its
third state: `undefined` means siteverify was never successfully consulted, which is NOT
the same as Cloudflare rejecting the token. Treating the two alike is the mistake this
field exists to prevent.

The analytically interesting number is usually not the per-visitor label but the RATE of
each verdict per traffic source. A referrer whose `unknown` rate is 90% when the site
average is 15% is the finding; an individual `unknown` is nothing.

USING IT EVERYWHERE AT ONCE
Add a built-in "Augment Event" transformation, set this variable as the value, and every
event reaching your tags carries the tsv_* parameters without editing a single tag. Send
tsv_score_bucket rather than tsv_score to GA4 to keep custom-dimension cardinality low,
and keep the raw score for BigQuery.
