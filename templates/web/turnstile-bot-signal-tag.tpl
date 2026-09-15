___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Turnstile Bot Signal",
  "categories": [
    "ANALYTICS",
    "UTILITY"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Configures and loads the first-party Cloudflare Turnstile bootstrap served by your server container, so a human-confidence verdict can be attached to your analytics data.",
  "containerContexts": [
    "WEB"
  ],
  "consentSettings": {
    "consentStatus": "notNeeded"
  }
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "endpoint",
    "displayName": "Verification endpoint",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^https://[^\\s?#]+$"
        ],
        "errorMessage": "Must be an https URL with no query string, e.g. https://sgtm.example.com/tsv"
      }
    ],
    "help": "The full URL of the Turnstile Verify client in your server container, e.g. <code>https://sgtm.example.com/tsv</code>. The bootstrap script is loaded from the same URL with <code>.js</code> appended.<br><br>This host <strong>must</strong> share a registrable domain with your website, or the verdict cookie is a third-party cookie and browsers will drop it."
  },
  {
    "type": "TEXT",
    "name": "sitekey",
    "displayName": "Turnstile site key",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "The public site key from the Cloudflare dashboard. Never the secret key — that one belongs only in the server container."
  },
  {
    "type": "TEXT",
    "name": "action",
    "displayName": "Action",
    "simpleValueType": true,
    "defaultValue": "page_view",
    "help": "Labels the challenge. Must match the <em>Expected action</em> in the server client, or the hit scores as <em>suspect</em>. Letters, digits, underscore and hyphen only; anything else is stripped."
  },
  {
    "type": "GROUP",
    "name": "advanced",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "cdata",
        "displayName": "Custom data",
        "simpleValueType": true,
        "help": "Optional correlation value passed through to the server. Useful for debugging; it carries no security weight, because whoever mints a token also controls this field."
      },
      {
        "type": "TEXT",
        "name": "container",
        "displayName": "Widget container selector",
        "simpleValueType": true,
        "help": "Optional CSS selector for the element the widget renders into. Leave empty to have one created. <strong>Whatever you point this at must stay renderable</strong> — Turnstile can escalate to a challenge a person has to click, and inside a <code>display:none</code> element they can never complete it."
      },
      {
        "type": "TEXT",
        "name": "absenceTimeout",
        "displayName": "Give up after (ms)",
        "simpleValueType": true,
        "defaultValue": "4000",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ],
        "help": "If no token has arrived by then, the browser sends the verification hit anyway with a reason code. This is what turns a blocked challenge into a measurable <em>unknown</em> instead of a silent hole in the data."
      },
      {
        "type": "TEXT",
        "name": "refreshBefore",
        "displayName": "Re-verify when less than (seconds) remain",
        "simpleValueType": true,
        "defaultValue": "300",
        "valueValidators": [
          {
            "type": "POSITIVE_NUMBER"
          }
        ],
        "help": "While an existing verdict has more time left than this, no new challenge is run."
      },
      {
        "type": "TEXT",
        "name": "stateCookie",
        "displayName": "State cookie name",
        "simpleValueType": true,
        "defaultValue": "_tsv_st",
        "help": "Must match the server client."
      },
      {
        "type": "CHECKBOX",
        "name": "debug",
        "checkboxText": "Log bootstrap activity to the browser console",
        "simpleValueType": true,
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const injectScript = require('injectScript');
const createQueue = require('createQueue');
const templateStorage = require('templateStorage');
const queryPermission = require('queryPermission');
const logToConsole = require('logToConsole');
const getUrl = require('getUrl');
const makeNumber = require('makeNumber');
const makeString = require('makeString');

// This tag does almost nothing on purpose. GTM's access_globals permission rejects any
// path whose first token is a predefined browser global, which rules out both
// `document.*` and `navigator.sendBeacon` -- so a web template can neither create the
// widget container nor beacon the token. The work happens in the first-party bootstrap
// script served by the server container, which is ordinary page JavaScript.

const endpoint = makeString(data.endpoint);
const scriptUrl = endpoint + '.js';

// A cross-site server container cannot set a usable verdict cookie. Warn rather than
// refuse: the registrable domain cannot be determined here without a public suffix
// list, so this check is a heuristic and would produce false alarms on multi-part TLDs.
const warnIfCrossSite = function () {
  const pageHost = getUrl('host');
  if (!pageHost) return;
  const parts = pageHost.split('.');
  if (parts.length < 2) return;
  const suffix = '.' + parts[parts.length - 2] + '.' + parts[parts.length - 1];
  if (endpoint.indexOf(suffix + '/') === -1 && endpoint.indexOf(suffix + ':') === -1) {
    logToConsole(
      '[turnstile] The verification endpoint does not look like it shares a registrable ' +
      'domain with ' + pageHost + '. The verdict cookie will be treated as third-party ' +
      'and dropped by most browsers.'
    );
  }
};

if (data.debug) warnIfCrossSite();

if (templateStorage.getItem('injected')) {
  // Already loaded on this page; the bootstrap verifies once per session regardless of
  // how many times this tag fires.
  data.gtmOnSuccess();
} else {
  const push = createQueue('tsvq');
  push({
    endpoint: endpoint,
    sitekey: makeString(data.sitekey),
    action: data.action ? makeString(data.action) : 'page_view',
    cdata: data.cdata ? makeString(data.cdata) : '',
    absenceTimeout: data.absenceTimeout ? makeNumber(data.absenceTimeout) : 4000,
    refreshBefore: data.refreshBefore ? makeNumber(data.refreshBefore) : 300,
    container: data.container ? makeString(data.container) : '',
    stateCookie: data.stateCookie ? makeString(data.stateCookie) : '_tsv_st',
    debug: data.debug === true
  });
  templateStorage.setItem('injected', true);

  if (queryPermission('inject_script', scriptUrl)) {
    injectScript(scriptUrl, data.gtmOnSuccess, data.gtmOnFailure, 'tsvBootstrap');
  } else {
    // The shipped permission has to be narrowed to your own endpoint after import.
    logToConsole('[turnstile] Not permitted to inject ' + scriptUrl +
      '. Add it to the Injects Scripts permission on this template.');
    data.gtmOnFailure();
  }
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "tsvq"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "any"
              }
            ]
          }
        },
        {
          "key": "allowedUrlParts",
          "value": {
            "type": 3,
            "mapKey": [
              {
                "type": 1,
                "string": "host"
              }
            ],
            "mapValue": [
              {
                "type": 8,
                "boolean": true
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Pushes the configuration and injects the bootstrap
  code: |-
    let pushed;
    mock('createQueue', () => (cfg) => { pushed = cfg; });
    let injected;
    mock('injectScript', (url, onSuccess) => { injected = url; onSuccess(); });

    runCode(mockData);

    assertThat(injected).isEqualTo('https://sgtm.example.com/tsv.js');
    assertThat(pushed.endpoint).isEqualTo('https://sgtm.example.com/tsv');
    assertThat(pushed.sitekey).isEqualTo('0x4AAAAAAA_test_sitekey');
    assertThat(pushed.action).isEqualTo('page_view');
    assertThat(pushed.absenceTimeout).isEqualTo(4000);
    assertApi('gtmOnSuccess').wasCalled();
- name: Applies defaults when the advanced fields are left empty
  code: |-
    let pushed;
    mock('createQueue', () => (cfg) => { pushed = cfg; });
    mock('injectScript', (url, onSuccess) => onSuccess());

    delete mockData.action;
    delete mockData.absenceTimeout;
    delete mockData.refreshBefore;
    delete mockData.stateCookie;

    runCode(mockData);

    assertThat(pushed.action).isEqualTo('page_view');
    assertThat(pushed.absenceTimeout).isEqualTo(4000);
    assertThat(pushed.refreshBefore).isEqualTo(300);
    assertThat(pushed.stateCookie).isEqualTo('_tsv_st');
- name: Injects only once however often the tag fires
  code: |-
    let injections = 0;
    mock('createQueue', () => () => {});
    mock('injectScript', (url, onSuccess) => { injections++; onSuccess(); });

    runCode(mockData);
    runCode(mockData);
    runCode(mockData);

    assertThat(injections, 'one challenge per page, not one per event').isEqualTo(1);
    assertApi('gtmOnSuccess').wasCalled();
- name: Fails cleanly when the injection permission has not been narrowed
  code: |-
    mock('createQueue', () => () => {});
    mock('queryPermission', () => false);
    let injected = false;
    mock('injectScript', () => { injected = true; });

    runCode(mockData);

    assertThat(injected).isFalse();
    assertApi('gtmOnFailure').wasCalled();
- name: Signals failure when the bootstrap cannot be loaded
  code: |-
    mock('createQueue', () => () => {});
    mock('injectScript', (url, onSuccess, onFailure) => onFailure());

    runCode(mockData);

    assertApi('gtmOnFailure').wasCalled();
setup: |-
  const mockData = {
    endpoint: 'https://sgtm.example.com/tsv',
    sitekey: '0x4AAAAAAA_test_sitekey',
    action: 'page_view',
    cdata: '',
    container: '',
    absenceTimeout: '4000',
    refreshBefore: '300',
    stateCookie: '_tsv_st',
    debug: false
  };

  mock('getUrl', () => 'www.example.com');


___NOTES___

Loads the first-party Turnstile bootstrap served by your server container. Fire it on
Initialisation (or Consent Initialisation) -- once per page is enough, and the bootstrap
itself only runs a challenge when the previous verdict is close to expiring.

AFTER IMPORTING, NARROW THE INJECTION PERMISSION
The template ships allowing script injection from any https host, because the endpoint
is yours and cannot be known in advance. Open the template's Permissions tab and replace
that entry with your own endpoint (e.g. https://sgtm.example.com/). The tag logs a
console message and reports failure if the URL it needs is not permitted.

WHY THIS TAG IS SO SMALL
GTM's access_globals permission rejects any path whose first token is a predefined
browser global, so a web template cannot touch `document` or call
`navigator.sendBeacon`. It can therefore neither create the widget container nor send
the token. The bootstrap script does both as ordinary page JavaScript; this tag only
writes configuration and loads it.

REQUIREMENTS
- The endpoint host must share a registrable domain with the site, or the verdict cookie
  is third-party and will be dropped.
- Your CSP must allow the endpoint host and https://challenges.cloudflare.com for both
  script-src and frame-src.
- If you point "Widget container selector" at your own element, keep it renderable.
  Turnstile can escalate to an interactive challenge, and a hidden container turns a
  real person into a timeout.

CONSENT
This tag declares that it does not require consent, on the basis that the bot check is a
security measure. Enriching analytics with the result is a different purpose from the
check itself -- if you operate under GDPR, have that distinction reviewed rather than
assuming it.
