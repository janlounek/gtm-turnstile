'use strict';

// Structural validation of the .tpl files themselves.
//
// A GTM template is only useful if it imports, and a template that does not import
// fails with a single unhelpful error in the UI. These tests catch the ways that
// happens — malformed JSON in a section, a section missing, a JavaScript syntax error,
// a permission id that does not exist, or sandboxed code reaching for something the
// sandbox does not have.

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');

const TEMPLATES = {
  'templates/web/turnstile-bot-signal-tag.tpl': {
    type: 'TAG',
    context: 'WEB',
    js: '___SANDBOXED_JS_FOR_WEB_TEMPLATE___',
    perms: '___WEB_PERMISSIONS___'
  },
  'templates/server/turnstile-verify-client.tpl': {
    type: 'CLIENT',
    context: 'SERVER',
    js: '___SANDBOXED_JS_FOR_SERVER___',
    perms: '___SERVER_PERMISSIONS___'
  },
  'templates/server/turnstile-verdict-variable.tpl': {
    type: 'MACRO',
    context: 'SERVER',
    js: '___SANDBOXED_JS_FOR_SERVER___',
    perms: '___SERVER_PERMISSIONS___'
  }
};

// Every section name GTM recognises, in the order it writes them.
const SECTION_RE = /^___[A-Z_]+___$/;

function sections(file) {
  const raw = fs.readFileSync(path.join(ROOT, file), 'utf8');
  const out = {};
  let current = null;
  let buf = [];
  for (const line of raw.split(/\r?\n/)) {
    if (SECTION_RE.test(line.trim())) {
      if (current) out[current] = buf.join('\n').trim();
      current = line.trim();
      buf = [];
    } else {
      buf.push(line);
    }
  }
  if (current) out[current] = buf.join('\n').trim();
  return out;
}

const KNOWN_PERMISSIONS = new Set([
  // web
  'inject_script', 'access_globals', 'access_template_storage', 'access_local_storage',
  'get_url', 'logging', 'send_pixel', 'read_data_layer', 'write_data_layer',
  'get_cookies', 'set_cookies', 'read_event_metadata', 'read_character_set',
  'read_title', 'access_consent', 'process_dom_events',
  // server
  'read_request', 'access_response', 'return_response', 'run_container', 'send_http',
  'read_event_data', 'access_firestore', 'access_bigquery', 'use_google_credentials',
  'send_pixel_from_browser'
]);

for (const [file, spec] of Object.entries(TEMPLATES)) {
  test(`${file}: has every required section`, () => {
    const s = sections(file);
    for (const required of ['___TERMS_OF_SERVICE___', '___INFO___', '___TEMPLATE_PARAMETERS___', spec.js, spec.perms, '___TESTS___', '___NOTES___']) {
      assert.ok(s[required] !== undefined, `missing ${required}`);
      assert.ok(s[required].length > 0, `empty ${required}`);
    }
  });

  test(`${file}: ___INFO___ is valid JSON describing the right template type`, () => {
    const info = JSON.parse(sections(file)['___INFO___']);
    assert.strictEqual(info.type, spec.type);
    assert.deepStrictEqual(info.containerContexts, [spec.context]);
    assert.ok(info.displayName);
    assert.ok(info.description);
  });

  // This is the test that catches a stray quote or angle bracket pasted into a help
  // string — the single most common way a hand-written .tpl fails to import.
  test(`${file}: ___TEMPLATE_PARAMETERS___ is valid JSON`, () => {
    const params = JSON.parse(sections(file)['___TEMPLATE_PARAMETERS___']);
    assert.ok(Array.isArray(params));
    assert.ok(params.length > 0);

    const names = [];
    const walk = (list) => {
      for (const p of list) {
        assert.ok(p.type, 'every parameter needs a type');
        if (p.type === 'GROUP') {
          assert.ok(Array.isArray(p.subParams), `${p.name}: GROUP needs subParams`);
          walk(p.subParams);
        } else {
          assert.ok(p.name, 'every parameter needs a name');
          names.push(p.name);
        }
      }
    };
    walk(params);
    assert.strictEqual(new Set(names).size, names.length, 'duplicate parameter names');
  });

  test(`${file}: ${spec.perms} is valid JSON with known permission ids`, () => {
    const perms = JSON.parse(sections(file)[spec.perms]);
    assert.ok(Array.isArray(perms));
    for (const p of perms) {
      const id = p.instance.key.publicId;
      assert.ok(KNOWN_PERMISSIONS.has(id), `unknown permission id: ${id}`);
      assert.ok(Array.isArray(p.instance.param), `${id}: param must be an array`);
      assert.strictEqual(p.isRequired, true, `${id}: isRequired must be true`);
    }
    const ids = perms.map((p) => p.instance.key.publicId);
    assert.strictEqual(new Set(ids).size, ids.length, 'duplicate permission entries');
  });

  test(`${file}: sandboxed JavaScript parses`, () => {
    const code = sections(file)[spec.js];
    // Wrapping in a Function body is how GTM runs it, so top-level `return` is legal
    // here exactly as it is in the sandbox.
    assert.doesNotThrow(() => new Function('data', code), 'syntax error in sandboxed JS');
  });

  test(`${file}: sandboxed JavaScript only requires APIs it declares`, () => {
    const code = sections(file)[spec.js];
    const required = [...code.matchAll(/require\('([^']+)'\)/g)].map((m) => m[1]);
    assert.ok(required.length > 0);
    assert.strictEqual(new Set(required).size, required.length, 'duplicate require() calls');
  });

  test(`${file}: ___TESTS___ looks like the scenario format GTM expects`, () => {
    const tests = sections(file)['___TESTS___'];
    assert.ok(tests.startsWith('scenarios:'), 'must start with scenarios:');
    assert.ok(tests.includes('runCode(mockData)'), 'no scenario actually runs the code');
    assert.ok(/^- name: /m.test(tests), 'no named scenarios');
  });
}

// --- cross-template invariants ---------------------------------------------

// Strips comments and the inlined bootstrap string literal. The bootstrap is ordinary
// browser JavaScript that happens to live inside the template as data — it is *supposed*
// to touch document and navigator, which is the whole reason it exists.
// Also strips string literals, so prose inside a console message is not mistaken for
// code — the checks below match bare tokens and cannot tell the difference themselves.
function executableSandboxCode(file, spec) {
  return sections(file)[spec.js]
    .replace(/^const TSV_BOOTSTRAP = ".*";$/m, 'const TSV_BOOTSTRAP = "";')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/'(?:[^'\\\n]|\\.)*'/g, "''")
    .replace(/"(?:[^"\\\n]|\\.)*"/g, '""');
}

test('the sandboxed code never touches globals the sandbox does not provide', () => {
  // GTM's access_globals rejects any path whose first token is a predefined browser
  // global, and the sandbox has no Date or RegExp constructor. Reaching for one of
  // these fails at runtime, not at import, so catch it here.
  const banned = [
    { re: /\bnew Date\b/, why: 'no Date in the sandbox; use getTimestampMillis()' },
    { re: /\bnew RegExp\b/, why: 'no RegExp in the sandbox' },
    { re: /\bnew \w/, why: 'the sandbox has no `new` keyword' },
    { re: /\bwindow\./, why: 'no window in the sandbox' },
    { re: /\bdocument\./, why: 'no document in the sandbox' },
    { re: /\bnavigator\./, why: 'no navigator in the sandbox' },
    { re: /\bthis\b/, why: 'the sandbox has no `this`' },
    { re: /\btry\s*\{/, why: 'the sandbox has no try/catch' },
    { re: /\bfor\s*\([^;)]*\bof\b/, why: 'no for...of in the sandbox' },
    { re: /`/, why: 'no template literals in the sandbox' }
  ];
  for (const [file, spec] of Object.entries(TEMPLATES)) {
    const code = executableSandboxCode(file, spec);
    for (const { re, why } of banned) {
      assert.ok(!re.test(code), `${file}: ${why}`);
    }
  }
});

test('the signing and verifying templates embed identical codec source', () => {
  // The whole point of the build step. If these ever differ, every verdict cookie
  // fails verification and every visitor silently becomes `unknown`.
  const extract = (file) => {
    const code = sections(file)['___SANDBOXED_JS_FOR_SERVER___'];
    const start = code.indexOf('// >>> GENERATED src/shared/verdict-codec.js');
    const end = code.indexOf('// <<< GENERATED src/shared/verdict-codec.js');
    assert.ok(start !== -1 && end > start, `${file}: codec block not found`);
    return code.slice(start, end);
  };
  assert.strictEqual(
    extract('templates/server/turnstile-verify-client.tpl'),
    extract('templates/server/turnstile-verdict-variable.tpl')
  );
});

test('the client embeds the bootstrap the web tag expects to load', () => {
  const code = sections('templates/server/turnstile-verify-client.tpl')['___SANDBOXED_JS_FOR_SERVER___'];
  assert.ok(code.includes('const TSV_BOOTSTRAP = "'), 'bootstrap string not inlined');
  assert.ok(code.includes('challenges.cloudflare.com'), 'bootstrap does not reference Turnstile');
  assert.ok(code.includes('setResponseBody(TSV_BOOTSTRAP)'), 'bootstrap is never served');
});

test('the browser bootstrap parses', () => {
  // Ordinary browser JavaScript rather than sandboxed code, but it ships inside the
  // client template as a string, so a syntax error here would only surface as a broken
  // page in production.
  const src = fs.readFileSync(path.join(ROOT, 'src/bootstrap/tsv.js'), 'utf8');
  assert.doesNotThrow(() => new Function(src), 'syntax error in the bootstrap');
  assert.ok(src.includes('sendBeacon'), 'bootstrap must have a transport');
  assert.ok(src.includes('prerendering'), 'bootstrap must guard against prerender');
  // Sending the hit even without a token is what makes "no signal" measurable.
  assert.ok(/send\(''\s*,\s*'sb'\)/.test(src), 'bootstrap must report a blocked script');
  assert.ok(/send\(''\s*,\s*'to'\)/.test(src), 'bootstrap must report a timeout');
});
