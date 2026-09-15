'use strict';

const crypto = require('node:crypto');

// The `deps` the sandboxed codec expects, backed by Node primitives. In GTM these are
// sha256Sync(s, {outputEncoding:'hex'}), makeNumber and generateRandom+getTimestampMillis.
const deps = {
  sha256hex: (s) => crypto.createHash('sha256').update(s, 'utf8').digest('hex'),
  toNumber: (s) => Number(s),
  nonce: () => crypto.randomBytes(16).toString('hex')
};

const KEYS = [
  { kid: 'k1', secret: 'secret-one-aaaaaaaaaaaaaaaaaaaaaaaa' },
  { kid: 'k2', secret: 'secret-two-bbbbbbbbbbbbbbbbbbbbbbbb' }
];

const NOW = 1757944800; // 2025-09-15T12:40:00Z, fixed so tests never depend on the clock

module.exports = { deps, KEYS, NOW };
