'use strict';

// Keeps the signer and the verifier byte-identical.
//
// GTM templates have no import mechanism, so the MAC and scoring code has to be
// physically duplicated into each .tpl. A single divergent character between the
// client that signs the cookie and the variable that verifies it would make every
// cookie fail validation and silently turn every visitor into `unknown` — a failure
// that looks like a data problem, not a code problem. So the .tpl copies are
// generated, and CI fails if anyone edits them by hand.

const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');

const STRIP = /^\/\/ BUILD:STRIP-START[\s\S]*?^\/\/ BUILD:STRIP-END\s*$/m;

const marker = (kind, src) => ({
  open: `// >>> ${kind} ${src}`,
  close: `// <<< ${kind} ${src}`
});

// The module body minus its CommonJS exports — the sandbox has no module system.
function sandboxSource(src) {
  const raw = fs.readFileSync(path.join(ROOT, src), 'utf8');
  if (!STRIP.test(raw)) {
    throw new Error(`${src}: missing BUILD:STRIP-START/END block`);
  }
  return raw.replace(STRIP, '').trimEnd();
}

function replaceBlock(tpl, open, close, body, src, tplName) {
  const start = tpl.indexOf(open);
  const end = tpl.indexOf(close);
  if (start === -1 || end === -1) {
    throw new Error(`${tplName}: missing marker for ${src}\n  expected:\n    ${open}\n    ${close}`);
  }
  if (end < start) {
    throw new Error(`${tplName}: markers for ${src} are out of order`);
  }
  return tpl.slice(0, start + open.length) + '\n' + body + '\n' + tpl.slice(end);
}

// What each template embeds. Adding a template means adding a line here.
const SPEC = {
  'templates/server/turnstile-verify-client.tpl': [
    { kind: 'GENERATED', src: 'src/shared/verdict-codec.js' },
    { kind: 'GENERATED', src: 'src/shared/scoring.js' },
    { kind: 'GENERATED-STRING', src: 'src/bootstrap/tsv.js', varName: 'TSV_BOOTSTRAP' }
  ],
  'templates/server/turnstile-verdict-variable.tpl': [
    { kind: 'GENERATED', src: 'src/shared/verdict-codec.js' }
  ]
};

function render(tplRel) {
  let tpl = fs.readFileSync(path.join(ROOT, tplRel), 'utf8');
  for (const block of SPEC[tplRel]) {
    const { open, close } = marker(block.kind, block.src);
    let body;
    if (block.kind === 'GENERATED') {
      body = sandboxSource(block.src);
    } else {
      // The bootstrap ships to the browser verbatim, so it is embedded as a single
      // JS string literal rather than as code.
      const raw = fs.readFileSync(path.join(ROOT, block.src), 'utf8');
      body = `const ${block.varName} = ${JSON.stringify(raw)};`;
    }
    tpl = replaceBlock(tpl, open, close, body, block.src, tplRel);
  }
  return tpl;
}

module.exports = { SPEC, render, ROOT };
