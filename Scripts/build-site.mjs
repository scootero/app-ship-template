#!/usr/bin/env node
// =============================================================================
// build-site.mjs — build the website from your store listing.      [opt] PHASE 5
// =============================================================================
// Reads:   ship.config, store/metadata/<first locale>.md, store/screenshots/
// Fills:   docs/site-template.html  →  docs/index.html
// Copies:  screenshots into docs/assets/screens/
//
// Runs automatically in .github/workflows/pages.yml on every push that
// touches store/ or docs/, then GitHub Pages publishes the result.
// Run it yourself to preview:
//     node Scripts/build-site.mjs && open docs/index.html
//
// No npm install needed (plain Node 18+).
// To change the LOOK: edit docs/site-template.html.
// To change the WORDS: edit store/metadata/<locale>.md (same text as the App Store).
// =============================================================================

import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const r = (...p) => path.join(ROOT, ...p);

// --- inputs -----------------------------------------------------------------
const config = Object.fromEntries(
  fs.readFileSync(r('ship.config'), 'utf8').split('\n')
    .map((l) => l.match(/^([A-Z_]+)=(?:"([^"]*)"|([^\s#]*))/)).filter(Boolean).map((m) => [m[1], m[2] ?? m[3] ?? '']),
);
const locale = (config.LOCALES || 'en-US').split(/\s+/)[0];
const metaFile = r('store/metadata', `${locale}.md`);
const meta = {};
for (const part of fs.readFileSync(metaFile, 'utf8').replace(/<!--[\s\S]*?-->/g, '').split(/^## /m).slice(1)) {
  const [key, ...rest] = part.split('\n');
  meta[key.trim()] = rest.join('\n').trim();
}

const esc = (s = '') => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// --- description: blank-line blocks; lines starting with • or - become a list
function descriptionHtml(text = '') {
  return text.split(/\n\s*\n/).map((block) => {
    const lines = block.split('\n').map((l) => l.trim()).filter(Boolean);
    const items = lines.filter((l) => /^[•\-*]\s+/.test(l));
    if (items.length && items.length === lines.length) {
      return `<ul>${items.map((l) => `<li>${esc(l.replace(/^[•\-*]\s+/, ''))}</li>`).join('')}</ul>`;
    }
    if (items.length) {   // "Heading:" line followed by bullets
      const head = lines.filter((l) => !/^[•\-*]\s+/.test(l));
      return `<p><strong>${esc(head.join(' '))}</strong></p><ul>${items.map((l) => `<li>${esc(l.replace(/^[•\-*]\s+/, ''))}</li>`).join('')}</ul>`;
    }
    return `<p>${esc(lines.join(' '))}</p>`;
  }).join('\n    ');
}

// --- screenshots: first device folder for the locale, copied into docs/ ------
function screenshotsHtml() {
  const base = r('store/screenshots', locale);
  if (!fs.existsSync(base)) return '';
  const preferred = ['iphone-6.9', 'mac', 'ipad-13'];
  const dirs = fs.readdirSync(base).filter((d) => fs.statSync(path.join(base, d)).isDirectory());
  const device = preferred.find((d) => dirs.includes(d)) ?? dirs[0];
  if (!device) return '';
  const pngs = fs.readdirSync(path.join(base, device)).filter((f) => /\.(png|jpe?g|webp)$/i.test(f)).sort();
  if (!pngs.length) return '';
  const out = r('docs/assets/screens');
  fs.rmSync(out, { recursive: true, force: true });
  fs.mkdirSync(out, { recursive: true });
  for (const f of pngs) fs.copyFileSync(path.join(base, device, f), path.join(out, f));
  const wide = device === 'mac' || device.startsWith('ipad') ? ' wide' : '';
  return `<div class="shots${wide}">${pngs.map((f) => `<img src="assets/screens/${f}" alt="" loading="lazy">`).join('')}</div>`;
}

// --- buttons ------------------------------------------------------------------
function ctaHtml() {
  const out = [];
  if (config.APP_STORE_URL) out.push(`<a class="cta" href="${esc(config.APP_STORE_URL)}">Download on the App Store</a>`);
  if (config.DOWNLOAD_URL) out.push(`<a class="cta${out.length ? ' secondary' : ''}" href="${esc(config.DOWNLOAD_URL)}">Download for Mac</a>`);
  if (!out.length) out.push('<a class="cta secondary" href="#support">Coming soon</a>');
  return out.join('\n    ');
}

const support = config.SUPPORT_EMAIL
  ? `<p>Questions or bugs? Email <a href="mailto:${esc(config.SUPPORT_EMAIL)}">${esc(config.SUPPORT_EMAIL)}</a> or open an issue on GitHub.</p>`
  : '<p>Questions or bugs? Open an issue on GitHub.</p>';

// --- fill the template --------------------------------------------------------
const tokens = {
  // Icon comes from Scripts/generate-icon.swift (or drop your own icon-512.png in docs/assets).
  ICON_HTML: fs.existsSync(r('docs/assets/icon-512.png')) ? '<img class="icon" src="assets/icon-512.png" alt="">' : '',
  DISPLAY_NAME: esc(config.DISPLAY_NAME || config.APP_NAME),
  SUBTITLE: esc(meta.subtitle),
  PROMO: esc(meta.promotional_text),
  DESCRIPTION_HTML: descriptionHtml(meta.description),
  SCREENSHOTS_HTML: screenshotsHtml(),
  CTA_HTML: ctaHtml(),
  SUPPORT_HTML: support,
  REPO_URL: esc(`https://github.com/${config.GITHUB_USER}/${config.APP_NAME}`),
  ACCENT: esc(config.SITE_ACCENT || '#00e5ff'),
  YEAR: String(new Date().getFullYear()),
};

let html = fs.readFileSync(r('docs/site-template.html'), 'utf8')
  .replace(/<!--[\s\S]*?-->\n?/, '<!-- GENERATED by Scripts/build-site.mjs — edit docs/site-template.html or store/metadata instead. -->\n');
html = html.replace(/\{\{([A-Z_]+)\}\}/g, (m, k) => (k in tokens ? tokens[k] : m));
fs.writeFileSync(r('docs/index.html'), html);

const left = [...html.matchAll(/TODO/g)].length;
console.log(`✓ docs/index.html built from ${path.relative(ROOT, metaFile)}${left ? ` (${left} TODO(s) still in the store text)` : ''}`);
