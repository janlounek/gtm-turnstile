'use strict';

const test = require('node:test');
const assert = require('node:assert');

const codec = require('../src/shared/verdict-codec.js');
const { deps, KEYS, NOW } = require('./helpers.js');

const sign = (over) =>
  codec.tsvEncode(deps, {
    kid: 'k1',
    secret: KEYS[0].secret,
    verdict: 'h',
    score: 95,
    iat: NOW,
    exp: NOW + 1800,
    bind: '3f9a1c2b',
    reasons: [],
    jti: '7f3a91c2',
    ...over
  });

const verify = (value, over) =>
  codec.tsvDecode(deps, { value, keys: KEYS, nowSec: NOW, ...over });

test('round trip preserves every field', () => {
  const out = verify(sign({ reasons: ['am', 'st'], score: 60, verdict: 's' }));
  assert.strictEqual(out.ok, true);
  assert.strictEqual(out.verdict, 's');
  assert.strictEqual(out.score, 60);
  assert.strictEqual(out.kid, 'k1');
  assert.strictEqual(out.iat, NOW);
  assert.strictEqual(out.exp, NOW + 1800);
  assert.strictEqual(out.bind, '3f9a1c2b');
  assert.deepStrictEqual(out.reasons, ['am', 'st']);
  assert.strictEqual(out.jti, '7f3a91c2');
});

test('a null score round trips as null, never as 0', () => {
  const out = verify(sign({ verdict: 'u', score: null }));
  assert.strictEqual(out.ok, true);
  assert.strictEqual(out.score, null);
  assert.notStrictEqual(out.score, 0);
});

test('cookie has exactly 10 dot-separated segments and a 32-hex MAC', () => {
  const parts = sign().split('.');
  assert.strictEqual(parts.length, codec.TSV_SEGMENTS);
  assert.strictEqual(parts[9].length, codec.TSV_MAC_LEN);
  assert.ok(/^[0-9a-f]{32}$/.test(parts[9]));
});

test('the second key in the ring verifies, so keys can be rotated', () => {
  const value = codec.tsvEncode(deps, {
    kid: 'k2',
    secret: KEYS[1].secret,
    verdict: 'h',
    score: 95,
    iat: NOW,
    exp: NOW + 1800,
    bind: '0',
    reasons: [],
    jti: 'abc123'
  });
  assert.strictEqual(verify(value).ok, true);
});

// --- negative cases ---------------------------------------------------------

test('tampering with the verdict is rejected', () => {
  const parts = sign({ verdict: 'b', score: 10 }).split('.');
  parts[2] = 'h';
  parts[3] = '95';
  const out = verify(parts.join('.'));
  assert.strictEqual(out.ok, false);
  assert.strictEqual(out.error, 'bad_mac');
});

test('a MAC from a different key is rejected', () => {
  const forged = codec.tsvEncode(deps, {
    kid: 'k1', // claims k1...
    secret: KEYS[1].secret, // ...but signed with k2's secret
    verdict: 'h',
    score: 95,
    iat: NOW,
    exp: NOW + 1800,
    bind: '0',
    reasons: [],
    jti: 'abc123'
  });
  assert.strictEqual(verify(forged).error, 'bad_mac');
});

test('an unknown key id is rejected before any MAC work', () => {
  assert.strictEqual(verify(sign()).ok, true);
  assert.strictEqual(verify(sign(), { keys: [KEYS[1]] }).error, 'unknown_kid');
});

test('an expired cookie is rejected even though its MAC is valid', () => {
  const value = sign({ exp: NOW - 1 });
  assert.strictEqual(verify(value).error, 'expired');
  assert.strictEqual(verify(value, { nowSec: NOW - 100 }).ok, true);
});

test('expiry is exclusive at the boundary second', () => {
  assert.strictEqual(verify(sign({ exp: NOW }), { nowSec: NOW }).error, 'expired');
  assert.strictEqual(verify(sign({ exp: NOW + 1 }), { nowSec: NOW }).ok, true);
});

test('a wrong version is rejected', () => {
  const parts = sign().split('.');
  parts[0] = '2';
  assert.strictEqual(verify(parts.join('.')).error, 'version');
});

// This is the attack the strict charset exists to stop: a '.' inside `reasons` would
// shift every later field by one position while leaving a structurally valid cookie.
test('a delimiter smuggled into reasons is refused at encode time', () => {
  assert.strictEqual(sign({ reasons: ['am.st'] }), '');
  assert.strictEqual(sign({ reasons: ['am.st.0.0.0'] }), '');
});

test('a delimiter smuggled into any field is refused at encode time', () => {
  assert.strictEqual(sign({ verdict: 'h.x' }), '');
  assert.strictEqual(sign({ jti: 'a.b' }), '');
  assert.strictEqual(sign({ kid: 'k.1' }), '');
});

test('an injected extra segment is rejected on read', () => {
  const parts = sign().split('.');
  parts.splice(8, 0, 'x');
  assert.strictEqual(verify(parts.join('.')).error, 'malformed');
});

test('garbage and empty input are rejected without throwing', () => {
  assert.strictEqual(verify('').error, 'absent');
  assert.strictEqual(verify(undefined).error, 'absent');
  assert.strictEqual(verify('not-a-cookie').error, 'malformed');
  assert.strictEqual(verify('a.b.c.d.e.f.g.h.i.j').error, 'version');
  assert.strictEqual(verify('x'.repeat(600)).error, 'malformed');
});

test('a segment with characters outside the allowed class is rejected on read', () => {
  const parts = sign().split('.');
  parts[2] = 'h+';
  assert.strictEqual(verify(parts.join('.')).error, 'malformed');
});

test('a non-numeric iat/exp is rejected on read', () => {
  // Signed properly, so this gets past the MAC and must still be caught.
  const value = codec.tsvEncode(deps, {
    kid: 'k1',
    secret: KEYS[0].secret,
    verdict: 'h',
    score: 95,
    iat: 'abcdefghij',
    exp: 'klmnopqrst',
    bind: '0',
    reasons: [],
    jti: 'abc123'
  });
  assert.strictEqual(verify(value).error, 'malformed');
});

// --- helpers ----------------------------------------------------------------

test('tsvPad10 produces fixed-width strings that sort like the numbers', () => {
  assert.strictEqual(codec.tsvPad10(5), '0000000005');
  assert.strictEqual(codec.tsvPad10(1757944800), '1757944800');
  assert.ok(codec.tsvPad10(999) < codec.tsvPad10(1000));
  assert.ok(codec.tsvPad10(1757944799) < codec.tsvPad10(1757944800));
});

test('tsvIpPrefix truncates IPv4 to /24 and IPv6 to the first four hextets', () => {
  assert.strictEqual(codec.tsvIpPrefix('203.0.113.42'), '203.0.113');
  assert.strictEqual(codec.tsvIpPrefix('2001:db8:85a3:8d3:1319:8a2e:370:7348'), '2001:db8:85a3:8d3');
  assert.strictEqual(codec.tsvIpPrefix(''), '');
  assert.strictEqual(codec.tsvIpPrefix('garbage'), 'garbage');
});

test('tsvBind never leaks the raw address', () => {
  const b = codec.tsvBind(deps, 'salt', '203.0.113.42', 'Mozilla/5.0');
  assert.strictEqual(b.length, 8);
  assert.ok(!b.includes('203'));
  // Same /24, different host -> same bind. Different /24 -> different bind.
  assert.strictEqual(b, codec.tsvBind(deps, 'salt', '203.0.113.99', 'Mozilla/5.0'));
  assert.notStrictEqual(b, codec.tsvBind(deps, 'salt', '198.51.100.42', 'Mozilla/5.0'));
  assert.notStrictEqual(b, codec.tsvBind(deps, 'salt', '203.0.113.42', 'curl/8'));
});

test('tsvBucket keeps GA4 dimension cardinality bounded', () => {
  assert.strictEqual(codec.tsvBucket(null), 'none');
  assert.strictEqual(codec.tsvBucket(0), '0-19');
  assert.strictEqual(codec.tsvBucket(19), '0-19');
  assert.strictEqual(codec.tsvBucket(20), '20-39');
  assert.strictEqual(codec.tsvBucket(60), '60-79');
  assert.strictEqual(codec.tsvBucket(95), '80-100');
  assert.strictEqual(codec.tsvBucket(100), '80-100');
});

test('tsvSafeEqual agrees with === on equality', () => {
  assert.strictEqual(codec.tsvSafeEqual(deps, 'abc', 'abc'), true);
  assert.strictEqual(codec.tsvSafeEqual(deps, 'abc', 'abd'), false);
  assert.strictEqual(codec.tsvSafeEqual(deps, 'abc', 'ab'), false);
  assert.strictEqual(codec.tsvSafeEqual(deps, 'abc', undefined), false);
});
