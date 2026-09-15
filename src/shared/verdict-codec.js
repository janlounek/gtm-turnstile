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

// BUILD:STRIP-START — removed when inlined into .tpl (the sandbox has no modules)
module.exports = {
  TSV_VERSION: TSV_VERSION,
  TSV_SEGMENTS: TSV_SEGMENTS,
  TSV_MAC_LEN: TSV_MAC_LEN,
  tsvIsSafe: tsvIsSafe,
  tsvIsDigits: tsvIsDigits,
  tsvPad10: tsvPad10,
  tsvMac: tsvMac,
  tsvSafeEqual: tsvSafeEqual,
  tsvEncode: tsvEncode,
  tsvDecode: tsvDecode,
  tsvIpPrefix: tsvIpPrefix,
  tsvBind: tsvBind,
  tsvCfSuccess: tsvCfSuccess,
  tsvBucket: tsvBucket
};
// BUILD:STRIP-END
