'use strict';

// Fails if a .tpl has drifted from src/ — i.e. someone edited the generated copy of
// the MAC code in one template but not the other. Runs in CI.

const fs = require('node:fs');
const path = require('node:path');
const { SPEC, render, ROOT } = require('./inline.js');

const stale = [];
for (const tplRel of Object.keys(SPEC)) {
  const current = fs.readFileSync(path.join(ROOT, tplRel), 'utf8');
  if (current !== render(tplRel)) stale.push(tplRel);
}

if (stale.length === 0) {
  console.log('Templates are in sync with src/.');
  process.exit(0);
}

console.error('Templates have drifted from src/:');
for (const f of stale) console.error(`  ${f}`);
console.error(
  '\nThe signing and verifying code must stay byte-identical, or every verdict cookie\n' +
    'fails validation and every visitor silently becomes `unknown`.\n' +
    'Edit src/ and run `npm run build` — never edit the generated block in a .tpl.'
);
process.exit(1);
