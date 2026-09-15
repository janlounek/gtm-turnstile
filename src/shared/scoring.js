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

// Reason codes, kept to two characters so a handful of them still fit a cookie segment.
//   am action mismatch      hm hostname not allowed   st stale challenge
//   rp replay (token reused) fg forged/invalid token  nh no token sent
//   sb challenge script blocked  to challenge timed out  er client-side error
//   cfg server misconfiguration  net siteverify unreachable  bm cookie bind mismatch

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
    reasons.push('net');
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
      reasons.push('net');
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
      reasons.push('nh');
      return out;
    }
    out.verdict = TSV_VERDICT_ERROR;
    reasons.push('net');
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

// BUILD:STRIP-START — removed when inlined into .tpl (the sandbox has no modules)
module.exports = {
  TSV_VERDICT_HUMAN: TSV_VERDICT_HUMAN,
  TSV_VERDICT_SUSPECT: TSV_VERDICT_SUSPECT,
  TSV_VERDICT_BOT: TSV_VERDICT_BOT,
  TSV_VERDICT_UNKNOWN: TSV_VERDICT_UNKNOWN,
  TSV_VERDICT_ERROR: TSV_VERDICT_ERROR,
  tsvDaysFromCivil: tsvDaysFromCivil,
  tsvParseIso: tsvParseIso,
  tsvHasCode: tsvHasCode,
  tsvScore: tsvScore
};
// BUILD:STRIP-END
