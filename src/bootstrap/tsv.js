/* Turnstile bot-signal bootstrap — CANONICAL SOURCE.
 *
 * Served first-party by the sGTM client at <endpoint>/tsv.js and inlined into
 * turnstile-verify-client.tpl by build/generate-tpl.js. Do not edit the copy in the
 * .tpl — edit here and run `npm run build`.
 *
 * Why this file exists at all: GTM's access_globals permission refuses any path whose
 * first token is a predefined browser global, which rules out both `document.*` and
 * `navigator.sendBeacon`. A web template therefore cannot create the widget container
 * or beacon the token. This runs as ordinary page JavaScript instead, with the web
 * template reduced to writing config and injecting this script.
 *
 * Config arrives as window.tsvq, an array the tag pushes into:
 *   { endpoint, sitekey, action, cdata, absenceTimeout, refreshBefore,
 *     container, stateCookie, debug }
 */
(function () {
  'use strict';

  var W = window;
  var D = document;
  var API = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=__tsvReady';
  var READY = '__tsvReady';
  var STATE = '__tsvState';

  if (W[STATE]) return; // already bootstrapped on this page
  W[STATE] = { sent: false, started: false };

  var cfg = null;
  var log = function () {};

  function drainQueue() {
    var q = W.tsvq;
    if (!q || !q.length) return null;
    return q[q.length - 1]; // last write wins; the tag only ever pushes one config
  }

  function clean(s, max) {
    if (typeof s !== 'string') return '';
    var out = '';
    for (var i = 0; i < s.length && out.length < max; i++) {
      var c = s.charAt(i);
      if ('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-'.indexOf(c) !== -1) {
        out += c;
      }
    }
    return out;
  }

  function readCookie(name) {
    var all = D.cookie ? D.cookie.split('; ') : [];
    for (var i = 0; i < all.length; i++) {
      if (all[i].indexOf(name + '=') === 0) return all[i].substring(name.length + 1);
    }
    return '';
  }

  /* ---- transport ------------------------------------------------------- */

  /* One hit per page, always sent — including when we failed to get a token. An
   * absent verification hit and a blocked challenge are indistinguishable at the
   * server otherwise, and "unknown with a cause" is a far more useful population
   * than a hole in the data. */
  function send(token, reason) {
    if (W[STATE].sent) return;
    W[STATE].sent = true;

    var body =
      'v=1&t=' + encodeURIComponent(token || 'none') +
      '&a=' + encodeURIComponent(cfg.action) +
      '&r=' + encodeURIComponent(reason || '');
    log('send', reason || 'token', body.length);

    // A string body is text/plain, which keeps this a CORS-simple request: no
    // preflight, credentials included, and Set-Cookie on the response is honoured.
    if (W.navigator && typeof W.navigator.sendBeacon === 'function') {
      if (W.navigator.sendBeacon(cfg.endpoint, body)) return;
    }
    if (typeof W.fetch === 'function') {
      W.fetch(cfg.endpoint, {
        method: 'POST',
        body: body,
        keepalive: true,
        mode: 'no-cors',
        credentials: 'include'
      })['catch'](function () {});
      return;
    }
    // Last resort. The token ends up in access logs here, hence the ordering.
    var img = new Image();
    img.src = cfg.endpoint + (cfg.endpoint.indexOf('?') === -1 ? '?' : '&') + body +
      '&cb=' + String(Math.random()).substring(2);
  }

  /* ---- widget ---------------------------------------------------------- */

  function container() {
    if (cfg.container) {
      var found = D.querySelector(cfg.container);
      if (found) return found;
      log('configured container not found, creating one');
    }
    var el = D.createElement('div');
    el.id = 'tsv-widget';
    /* Deliberately NOT display:none. With appearance:'interaction-only' Turnstile
     * renders nothing until it decides a human must click something; inside a hidden
     * container that human can never complete it, times out, and gets scored as
     * suspicious. Zero-footprint but renderable. */
    el.style.cssText =
      'position:fixed;right:0;bottom:0;width:0;height:0;overflow:visible;z-index:2147483647';
    D.body.appendChild(el);
    return el;
  }

  function challenge() {
    var el = container();
    var id;
    var params = {
      sitekey: cfg.sitekey,
      action: cfg.action,
      execution: 'execute',
      appearance: 'interaction-only',
      size: 'flexible',
      retry: 'never',
      callback: function (token) {
        log('token received');
        send(token, '');
        W.turnstile.remove(id);
      },
      'error-callback': function (code) {
        log('error-callback', code);
        send('', 'er');
        return true; // we handled it; do not let Turnstile surface an error widget
      },
      'timeout-callback': function () {
        log('timeout-callback');
        send('', 'to');
      }
    };
    if (cfg.cdata) params.cdata = cfg.cdata;

    id = W.turnstile.render(el, params);
    W.turnstile.execute(id);
  }

  function loadApi() {
    /* Already on the page, loaded by something else. render() being a function means
     * the API is initialised, so there is nothing to wait for. */
    if (W.turnstile && typeof W.turnstile.render === 'function') {
      challenge();
      return;
    }

    /* The onload query parameter is Turnstile's documented hook for asynchronous
     * loading, and the only correct one here: turnstile.ready() throws outright
     * ("Remove async/defer from the Turnstile api.js script tag before using
     * turnstile.ready()") when the script tag carries async or defer, which this one
     * must, since it is injected. */
    W[READY] = function () {
      challenge();
    };

    var s = D.createElement('script');
    s.src = API;
    s.async = true;
    s.defer = true;
    /* Blocked by an ad blocker, a CSP that omits challenges.cloudflare.com, or a
     * network failure. Reported as its own reason code so the resulting `unknown`
     * is attributable rather than mysterious. */
    s.onerror = function () {
      log('api.js blocked');
      send('', 'sb');
    };
    D.head.appendChild(s);
  }

  /* ---- entry ----------------------------------------------------------- */

  function start() {
    if (W[STATE].started) return;
    W[STATE].started = true;

    /* A live verdict cookie is still good, so do not burn a challenge. _tsv_st holds
     * only the expiry, which is why the verdict cookie itself can stay HttpOnly. */
    var st = readCookie(cfg.stateCookie);
    if (st && /^[0-9]{1,12}$/.test(st)) {
      var remaining = parseInt(st, 10) - Math.floor(Date.now() / 1000);
      if (remaining > cfg.refreshBefore) {
        log('verdict still valid for', remaining, 's — skipping');
        return;
      }
    }

    /* Nothing may be sent before the absence timer is armed: without it a blocked
     * api.js produces no hit at all and the visitor silently vanishes from the data. */
    W.setTimeout(function () {
      send('', 'to');
    }, cfg.absenceTimeout);

    loadApi();
  }

  function boot() {
    var raw = drainQueue();
    if (!raw || !raw.endpoint || !raw.sitekey) return;

    cfg = {
      endpoint: raw.endpoint,
      sitekey: raw.sitekey,
      action: clean(raw.action, 32) || 'page_view',
      cdata: clean(raw.cdata, 255),
      absenceTimeout: raw.absenceTimeout > 0 ? raw.absenceTimeout : 4000,
      refreshBefore: raw.refreshBefore > 0 ? raw.refreshBefore : 300,
      container: typeof raw.container === 'string' ? raw.container : '',
      stateCookie: raw.stateCookie || '_tsv_st',
      debug: !!raw.debug
    };
    if (cfg.debug && W.console) {
      log = function () {
        var a = ['[tsv]'];
        for (var i = 0; i < arguments.length; i++) a.push(arguments[i]);
        W.console.log.apply(W.console, a);
      };
    }

    /* Speculation-rules prerenders run this script in pages the user may never visit.
     * Minting a token there spends a single-use credential on a phantom session and is
     * a common source of mystery timeout-or-duplicate floods. */
    if (D.prerendering) {
      D.addEventListener('prerenderingchange', start, { once: true });
      return;
    }
    if (D.body) start();
    else D.addEventListener('DOMContentLoaded', start, { once: true });
  }

  boot();
})();
