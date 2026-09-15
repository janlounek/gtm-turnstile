'use strict';

// Regenerates the inlined blocks in each .tpl from src/. Run after touching anything
// under src/shared or src/bootstrap.

const fs = require('node:fs');
const path = require('node:path');
const { SPEC, render, ROOT } = require('./inline.js');

let changed = 0;
for (const tplRel of Object.keys(SPEC)) {
  const file = path.join(ROOT, tplRel);
  const before = fs.readFileSync(file, 'utf8');
  const after = render(tplRel);
  if (before === after) {
    console.log(`  unchanged  ${tplRel}`);
    continue;
  }
  fs.writeFileSync(file, after);
  console.log(`  written    ${tplRel}`);
  changed++;
}

console.log(changed === 0 ? '\nAll templates already up to date.' : `\n${changed} template(s) updated.`);
