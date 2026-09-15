'use strict';

const test = require('node:test');
const assert = require('node:assert');

const scoring = require('../src/shared/scoring.js');
const { deps, NOW } = require('./helpers.js');

const ALLOWED = ['shop.example.com', 'www.example.com'];

const at = (offsetSec) => new Date((NOW - offsetSec) * 1000).toISOString();

const run = (over) =>
  scoring.tsvScore(deps, {
    tokenPresent: true,
    clientReason: '',
    transport: 'ok',
    body: null,
    expectedAction: 'page_view',
    allowedHostnames: ALLOWED,
    maxAgeSec: 120,
    nowSec: NOW,
    ...over
  });

const ok = (over) => ({
  success: true,
  'error-codes': [],
  hostname: 'shop.example.com',
  action: 'page_view',
  challenge_ts: at(5),
  ...over
});

const fail = (codes) => ({ success: false, 'error-codes': codes });

// --- the happy path ---------------------------------------------------------

test('solved, on an allowed hostname, fresh -> human 95', () => {
  const r = run({ body: ok() });
  assert.strictEqual(r.verdict, 'h');
  assert.strictEqual(r.score, 95);
  assert.deepStrictEqual(r.reasons, []);
  assert.strictEqual(r.hostname, 'shop.example.com');
  assert.strictEqual(r.challengeAge, 5);
});

test('hostname comparison is case-insensitive', () => {
  assert.strictEqual(run({ body: ok({ hostname: 'SHOP.Example.COM' }) }).verdict, 'h');
});

test('an empty expected action accepts any action', () => {
  const r = run({ expectedAction: '', body: ok({ action: 'anything_at_all' }) });
  assert.strictEqual(r.verdict, 'h');
  assert.strictEqual(r.score, 95);
});

test('age erodes the score without changing the verdict', () => {
  assert.strictEqual(run({ body: ok({ challenge_ts: at(30) }) }).score, 95);
  assert.strictEqual(run({ body: ok({ challenge_ts: at(90) }) }).score, 90);

  const stale = run({ body: ok({ challenge_ts: at(200) }) });
  assert.strictEqual(stale.verdict, 'h');
  assert.strictEqual(stale.score, 85);
  assert.deepStrictEqual(stale.reasons, ['st']);
});

test('a challenge_ts in the future clamps to age 0 rather than going negative', () => {
  const r = run({ body: ok({ challenge_ts: at(-60) }) });
  assert.strictEqual(r.challengeAge, 0);
  assert.strictEqual(r.score, 95);
});

test('an unparseable challenge_ts leaves the score alone and reports no age', () => {
  const r = run({ body: ok({ challenge_ts: 'not-a-timestamp' }) });
  assert.strictEqual(r.verdict, 'h');
  assert.strictEqual(r.score, 95);
  assert.strictEqual(r.challengeAge, null);
});

// --- the assertion that actually matters ------------------------------------

test('a token minted on someone else’s site is a bot, not a human', () => {
  // The sitekey is public, so success:true from an unlisted hostname is the single
  // strongest signal siteverify gives us.
  const r = run({ body: ok({ hostname: 'attacker.example.net' }) });
  assert.strictEqual(r.verdict, 'b');
  assert.strictEqual(r.score, 25);
  assert.deepStrictEqual(r.reasons, ['hm']);
});

test('hostname is checked before action, so an off-site token cannot score suspect', () => {
  const r = run({ body: ok({ hostname: 'attacker.example.net', action: 'wrong' }) });
  assert.strictEqual(r.verdict, 'b');
  assert.deepStrictEqual(r.reasons, ['hm']);
});

test('an action mismatch on our own hostname is only suspect', () => {
  const r = run({ body: ok({ action: 'checkout' }) });
  assert.strictEqual(r.verdict, 's');
  assert.strictEqual(r.score, 60);
  assert.deepStrictEqual(r.reasons, ['am']);
});

test('an action mismatch never raises an already-lower score', () => {
  const r = run({ body: ok({ action: 'checkout', challenge_ts: at(200) }) });
  assert.strictEqual(r.score, 60);
  assert.deepStrictEqual(r.reasons, ['st', 'am']);
});

// --- error codes ------------------------------------------------------------

test('a forged token is a bot', () => {
  const r = run({ body: fail(['invalid-input-response']) });
  assert.strictEqual(r.verdict, 'b');
  assert.strictEqual(r.score, 10);
  assert.deepStrictEqual(r.reasons, ['fg']);
});

test('a replayed token is suspect, not bot', () => {
  // A double-fired tag or a bfcache restore lands here too.
  const r = run({ body: fail(['timeout-or-duplicate']) });
  assert.strictEqual(r.verdict, 's');
  assert.strictEqual(r.score, 30);
  assert.deepStrictEqual(r.reasons, ['rp']);
});

test('a bad secret key is our error, not the visitor’s', () => {
  for (const code of ['missing-input-secret', 'invalid-input-secret', 'bad-request']) {
    const r = run({ body: fail([code]) });
    assert.strictEqual(r.verdict, 'e', code);
    assert.strictEqual(r.score, null, code);
    assert.deepStrictEqual(r.reasons, ['cfg'], code);
  }
});

test('a Cloudflare internal error is an error verdict', () => {
  const r = run({ body: fail(['internal-error']) });
  assert.strictEqual(r.verdict, 'e');
  assert.strictEqual(r.score, null);
  assert.deepStrictEqual(r.reasons, ['net']);
});

test('an unrecognised error code degrades to error rather than to bot', () => {
  const r = run({ body: fail(['some-future-code']) });
  assert.strictEqual(r.verdict, 'e');
  assert.strictEqual(r.score, null);
});

test('missing-input-response is unknown, not bot', () => {
  const r = run({ body: fail(['missing-input-response']) });
  assert.strictEqual(r.verdict, 'u');
  assert.strictEqual(r.score, null);
  assert.deepStrictEqual(r.reasons, ['nh']);
});

// --- absence of signal ------------------------------------------------------

test('no token at all is unknown with a null score, never 0', () => {
  const r = run({ tokenPresent: false });
  assert.strictEqual(r.verdict, 'u');
  assert.strictEqual(r.score, null);
  assert.notStrictEqual(r.score, 0);
  assert.deepStrictEqual(r.reasons, ['nh']);
});

test('the browser’s reason for having no token is preserved', () => {
  // This is why the client sends the hit even when it failed: it converts a silent
  // hole in the data into a measured population with a cause.
  assert.deepStrictEqual(run({ tokenPresent: false, clientReason: 'sb' }).reasons, ['sb']);
  assert.deepStrictEqual(run({ tokenPresent: false, clientReason: 'to' }).reasons, ['to']);
  assert.deepStrictEqual(run({ tokenPresent: false, clientReason: 'er' }).reasons, ['er']);
  assert.strictEqual(run({ tokenPresent: false, clientReason: 'sb' }).verdict, 'u');
});

test('siteverify being unreachable is an error, not a judgement about the visitor', () => {
  for (const input of [
    { transport: 'failed', body: null },
    { transport: 'failed', body: ok() },
    { transport: 'ok', body: null }
  ]) {
    const r = run(input);
    assert.strictEqual(r.verdict, 'e');
    assert.strictEqual(r.score, null);
    assert.deepStrictEqual(r.reasons, ['net']);
  }
});

test('no outcome except human/suspect/bot ever carries a numeric score', () => {
  const cases = [
    { tokenPresent: false },
    { transport: 'failed', body: null },
    { body: fail(['internal-error']) },
    { body: fail(['invalid-input-secret']) },
    { body: fail(['missing-input-response']) }
  ];
  for (const c of cases) {
    const r = run(c);
    assert.ok(r.verdict === 'u' || r.verdict === 'e', JSON.stringify(c));
    assert.strictEqual(r.score, null, JSON.stringify(c));
  }
});

// --- the hand-rolled date parser -------------------------------------------

test('tsvParseIso matches Date.UTC across a range of timestamps', () => {
  // The sandbox has no Date, so this arithmetic is hand-rolled; pin it against the
  // real thing, including leap years and century boundaries.
  const samples = [
    '1970-01-01T00:00:00Z',
    '1999-12-31T23:59:59Z',
    '2000-02-29T12:00:00Z',
    '2024-02-29T23:59:59Z',
    '2026-09-15T18:53:00Z',
    '2026-01-01T00:00:00.000Z',
    '2026-12-31T23:59:59.999Z',
    '2100-03-01T00:00:00Z'
  ];
  for (const s of samples) {
    assert.strictEqual(
      scoring.tsvParseIso(s, Number),
      Math.floor(Date.parse(s) / 1000),
      s
    );
  }
});

test('tsvParseIso returns null on anything malformed rather than guessing', () => {
  const bad = [
    '', 'not-a-timestamp', '2026-09-15', '2026-09-15 18:53:00Z',
    '20260915T185300Z', '2026-13-01T00:00:00Z', '2026-00-01T00:00:00Z',
    '2026-09-32T00:00:00Z', '2026-09-15T24:00:00Z', '2026-09-15T00:60:00Z',
    'xxxx-09-15T18:53:00Z', null, undefined, 12345
  ];
  for (const s of bad) {
    assert.strictEqual(scoring.tsvParseIso(s, Number), null, String(s));
  }
});
