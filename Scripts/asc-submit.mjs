#!/usr/bin/env node
// =============================================================================
// asc-submit.mjs — push a release to the App Store with no clicking.  [core] PHASE 3
// =============================================================================
// Talks to Apple's App Store Connect API (the same thing the website uses).
// Called by .github/workflows/apple-store.yml when you push a v* tag, but you
// can run it from your Mac too.
//
// What it does, in order. Each step is safe to re-run if something hiccups:
//   1. Finds your app by bundle ID.
//   2. Waits for the TestFlight build with this version number to finish
//      processing (Xcode Cloud uploads it when you push to main).
//   3. Finds or creates the App Store version (e.g. "1.2.0").
//   4. Copies store text from store/metadata/<locale>.md into every language:
//      description, keywords, promotional text, URLs, What's New.
//   5. Attaches the build to the version.
//   6. Submits it for App Review (skip with --no-submit).
//
// Usage:
//   node Scripts/asc-submit.mjs --version 1.2.0 --platform IOS [--dry-run] [--no-submit]
//   node Scripts/asc-submit.mjs --metadata-only --platform IOS   # just sync store text
//
//   --platform       IOS | MAC_OS
//   --dry-run        read everything, change nothing, print what WOULD happen
//   --no-submit      do steps 1–5, leave the final "Submit" button to you
//   --metadata-only  step 4 only, on the version currently being prepared
//   --wait-minutes   how long to wait for the build (default 90)
//
// Env (GitHub secrets in CI; export in your shell locally):
//   ASC_API_KEY_ID      e.g. 2X9R4HXF34
//   ASC_API_ISSUER_ID   UUID shown above the keys list in App Store Connect
//   ASC_API_KEY_P8      the full text of the downloaded AuthKey_XXXX.p8 file
//                       (or ASC_API_KEY_PATH=/path/to/AuthKey_XXXX.p8)
//   BUNDLE_ID           defaults to BUNDLE_ID_PREFIX.APP_NAME from ship.config
//
// No npm install needed — Node 18+ has fetch and crypto built in.
//
// Written for this template; the idea comes from Blip's asc-autosubmit.mjs
// (github.com/blaineam/Blip, MIT). Theirs matches Xcode Cloud builds by git
// commit; this one matches by version number, which is simpler but means:
// RULE: bump the version before the release commit, so the newest build for
// "1.2.0" is the one you meant to ship.
//
// ⚠ TEST FIRST with --dry-run. The first real run is worth watching.
// API docs: https://developer.apple.com/documentation/appstoreconnectapi
// =============================================================================

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

// --- args ---------------------------------------------------------------------
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const PLATFORM = opt('platform', 'IOS');
const VERSION = opt('version');
const DRY = flag('dry-run');
const NO_SUBMIT = flag('no-submit');
const METADATA_ONLY = flag('metadata-only');
const WAIT_MIN = Number(opt('wait-minutes', 90));
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');

if (!['IOS', 'MAC_OS'].includes(PLATFORM)) die(`--platform must be IOS or MAC_OS`);
if (!METADATA_ONLY && !/^\d+\.\d+\.\d+$/.test(VERSION ?? '')) die('--version X.Y.Z is required');

// --- ship.config (plain KEY="value" lines) -------------------------------------
const config = Object.fromEntries(
  fs.readFileSync(path.join(ROOT, 'ship.config'), 'utf8')
    .split('\n')
    .map((l) => l.match(/^([A-Z_]+)="?(.*?)"?\s*$/))
    .filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const BUNDLE_ID = process.env.BUNDLE_ID || `${config.BUNDLE_ID_PREFIX}.${config.APP_NAME}`;

// --- auth: a short-lived signed token (JWT) made from your API key -----------
const KEY_ID = need('ASC_API_KEY_ID');
const ISSUER = need('ASC_API_ISSUER_ID');
const P8 = process.env.ASC_API_KEY_P8 || (process.env.ASC_API_KEY_PATH && fs.readFileSync(process.env.ASC_API_KEY_PATH, 'utf8'));
if (!P8) die('Set ASC_API_KEY_P8 (key text) or ASC_API_KEY_PATH (key file)');

function token() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const body = b64({ iss: ISSUER, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }); // Apple max: 20 min
  const sig = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: P8, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${sig.toString('base64url')}`;
}

// --- tiny API client --------------------------------------------------------
async function api(method, url, body) {
  const writes = method !== 'GET';
  if (writes && DRY) {
    log(`  [dry-run] ${method} ${url}`);
    return { data: { id: 'DRY_RUN', attributes: {} } };
  }
  const res = await fetch(`https://api.appstoreconnect.apple.com${url}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 204) return {};
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = (json.errors ?? []).map((e) => `${e.title}: ${e.detail}`).join('\n  ');
    throw new Error(`${method} ${url} → ${res.status}\n  ${detail}`);
  }
  return json;
}

// --- store/metadata/<locale>.md → { description, keywords, ... } ------------
// Each "## key" heading starts a field; HTML comments are stripped.
function readMetadata() {
  const dir = path.join(ROOT, 'store/metadata');
  const out = {};
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.md'))) {
    const text = fs.readFileSync(path.join(dir, file), 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    const fields = {};
    for (const part of text.split(/^## /m).slice(1)) {
      const [key, ...rest] = part.split('\n');
      fields[key.trim()] = rest.join('\n').trim();
    }
    out[file.replace(/\.md$/, '')] = fields;
  }
  return out;
}

// Only these live on the *version* localization. name + subtitle live on
// "app info" and rarely change — set those once by hand in App Store Connect.
const VERSION_FIELDS = {
  description: 'description',
  keywords: 'keywords',
  promotional_text: 'promotionalText',
  support_url: 'supportUrl',
  marketing_url: 'marketingUrl',
  whats_new: 'whatsNew',
};

// ============================================================================
async function main() {
  log(`→ ${BUNDLE_ID} · ${PLATFORM} · ${METADATA_ONLY ? 'metadata only' : `v${VERSION}`}${DRY ? ' · DRY RUN' : ''}`);

  // 1. App
  const apps = await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}`);
  const app = apps.data?.[0] ?? die(`No App Store Connect app with bundle ID ${BUNDLE_ID}. Create it first (SETUP.md).`);
  log(`✓ app ${app.attributes.name} (${app.id})`);

  // 2. Build
  let build;
  if (!METADATA_ONLY) build = await waitForBuild(app.id);

  // 3. Version
  const version = await findOrCreateVersion(app.id);

  // 4. Store text
  await syncMetadata(version, { isFirstVersion: VERSION === '1.0.0' || VERSION === '1.0' });
  if (METADATA_ONLY) return log('✓ metadata synced');

  // 5. Attach build
  await api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, {
    data: { type: 'builds', id: build.id },
  });
  log(`✓ build ${build.attributes.version} attached`);

  // 6. Submit
  if (NO_SUBMIT) return log('✓ ready — press "Add for Review" in App Store Connect when you want (--no-submit)');
  await submitForReview(app.id, version.id);
  log('✓ submitted for App Review 🚀');
}

async function waitForBuild(appId) {
  const url =
    `/v1/builds?filter[app]=${appId}` +
    `&filter[preReleaseVersion.version]=${VERSION}` +
    `&filter[preReleaseVersion.platform]=${PLATFORM}` +
    `&sort=-uploadedDate&limit=1`;
  const deadline = Date.now() + WAIT_MIN * 60_000;
  for (;;) {
    const b = (await api('GET', url)).data?.[0];
    const state = b?.attributes?.processingState;
    if (state === 'VALID') {
      log(`✓ build ${VERSION} (${b.attributes.version}) is processed`);
      return b;
    }
    if (state === 'FAILED' || state === 'INVALID') die(`Build ${VERSION} processing ${state}. Check App Store Connect → TestFlight.`);
    if (DRY) {
      log(`  [dry-run] no processed build for ${VERSION} yet (${state ?? 'not uploaded'}) — a real run would wait`);
      return { id: 'DRY_RUN', attributes: { version: '?' } };
    }
    if (Date.now() > deadline) die(`Timed out after ${WAIT_MIN} min waiting for build ${VERSION}. Did Xcode Cloud upload it?`);
    log(`  … build ${VERSION}: ${state ?? 'not uploaded yet'}, checking again in 60s`);
    await new Promise((r) => setTimeout(r, 60_000));
  }
}

async function findOrCreateVersion(appId) {
  const list = await api('GET', `/v1/apps/${appId}/appStoreVersions?filter[platform]=${PLATFORM}&limit=20`);
  const state = (v) => v.attributes.appVersionState ?? v.attributes.appStoreState;
  const editable = (v) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(state(v));

  if (METADATA_ONLY) {
    const v = list.data.find(editable);
    if (!v) {
      // Not an error: nothing is in preparation, so there's nowhere to write.
      log('• No version being prepared on this platform — nothing to sync. (A release run will push the text.)');
      process.exit(0);
    }
    log(`✓ version ${v.attributes.versionString} (${state(v)})`);
    return v;
  }

  const exact = list.data.find((v) => v.attributes.versionString === VERSION);
  if (exact) {
    if (!editable(exact)) die(`Version ${VERSION} is already ${state(exact)}. Bump the version.`);
    log(`✓ version ${VERSION} exists (${state(exact)})`);
    return exact;
  }
  // Apple allows only one version "in preparation" per platform: rename it.
  const draft = list.data.find(editable);
  if (draft) {
    log(`→ renaming draft version ${draft.attributes.versionString} → ${VERSION}`);
    return (await api('PATCH', `/v1/appStoreVersions/${draft.id}`, {
      data: { type: 'appStoreVersions', id: draft.id, attributes: { versionString: VERSION } },
    })).data;
  }
  log(`→ creating version ${VERSION}`);
  return (await api('POST', '/v1/appStoreVersions', {
    data: {
      type: 'appStoreVersions',
      attributes: { platform: PLATFORM, versionString: VERSION },
      relationships: { app: { data: { type: 'apps', id: appId } } },
    },
  })).data;
}

async function syncMetadata(version, { isFirstVersion }) {
  const meta = readMetadata();
  const existing = version.id === 'DRY_RUN' ? { data: [] }
    : await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`);

  for (const [locale, fields] of Object.entries(meta)) {
    const attributes = {};
    for (const [mdKey, apiKey] of Object.entries(VERSION_FIELDS)) {
      if (fields[mdKey]) attributes[apiKey] = fields[mdKey];
    }
    // Apple rejects "What's New" on an app's very first version.
    if (isFirstVersion) delete attributes.whatsNew;
    if (!Object.keys(attributes).length) continue;

    const loc = existing.data.find((l) => l.attributes.locale === locale);
    if (loc) {
      await api('PATCH', `/v1/appStoreVersionLocalizations/${loc.id}`, {
        data: { type: 'appStoreVersionLocalizations', id: loc.id, attributes },
      });
    } else {
      await api('POST', '/v1/appStoreVersionLocalizations', {
        data: {
          type: 'appStoreVersionLocalizations',
          attributes: { locale, ...attributes },
          relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
        },
      });
    }
    log(`✓ ${locale}: ${Object.keys(attributes).join(', ')}`);
  }
}

async function submitForReview(appId, versionId) {
  // Reuse an open (unsent) submission if a previous run got halfway.
  const open = await api('GET',
    `/v1/reviewSubmissions?filter[app]=${appId}&filter[platform]=${PLATFORM}&filter[state]=READY_FOR_REVIEW`);
  const sub = open.data?.[0] ?? (await api('POST', '/v1/reviewSubmissions', {
    data: {
      type: 'reviewSubmissions',
      attributes: { platform: PLATFORM },
      relationships: { app: { data: { type: 'apps', id: appId } } },
    },
  })).data;

  await api('POST', '/v1/reviewSubmissionItems', {
    data: {
      type: 'reviewSubmissionItems',
      relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: sub.id } },
        appStoreVersion: { data: { type: 'appStoreVersions', id: versionId } },
      },
    },
  }).catch((e) => {
    // Already added by an earlier run → fine, keep going.
    if (!/already|409/.test(e.message)) throw e;
  });

  await api('PATCH', `/v1/reviewSubmissions/${sub.id}`, {
    data: { type: 'reviewSubmissions', id: sub.id, attributes: { submitted: true } },
  });
}

// --- helpers ----------------------------------------------------------------
function need(name) {
  return process.env[name] || die(`Missing env var ${name} (see SETUP.md → App Store Connect API key)`);
}
function log(msg) { console.log(msg); }
function die(msg) { console.error(`✗ ${msg}`); process.exit(1); }

main().catch((e) => die(e.message));
