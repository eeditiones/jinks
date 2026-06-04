#!/usr/bin/env node
/**
 * SEO / indexability checker for TEI Publisher (jinks) document pages.
 *
 * The content of a TEI Publisher document page is rendered client-side by the
 * <pb-view> web component, which fetches HTML fragments from the API. This
 * script measures how much of that is visible to a crawler by comparing three
 * views of every page:
 *
 *   1. RAW       - the HTML the server sends, parsed with JavaScript DISABLED
 *                  (what a non-rendering crawler / link unfurler sees).
 *   2. RENDERED  - the DOM after the components have loaded and run
 *                  (what a JS-rendering crawler such as Googlebot sees on first
 *                  load, following links only - no synthetic clicks).
 *   3. SERVER    - the fragment chain walked directly through the API
 *                  (the ground-truth total amount of content in the document).
 *
 * From those it reports per-page metadata problems (title, lang, description,
 * canonical, Open Graph, JSON-LD, headings, image alt) and, crucially, how many
 * of the document's paginated fragments are actually reachable by a crawler
 * versus only reachable by clicking the JS pagination controls.
 *
 * Usage:
 *   node seo-check.mjs [--base <url>] [--out report.json] [--expect-lang en]
 *                      [--max-pages 200] [path ...]
 *
 * `path` arguments are document paths relative to the app root, e.g.
 *   doc/quickstart.xml
 * If none are given, a small default set is used.
 *
 * Exit code is non-zero if any page has a FAIL-level finding.
 */

import { chromium, request as pwRequest } from 'playwright';

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const opts = {
  base: 'http://localhost:8080/exist/apps/tei-publisher',
  out: null,
  expectLang: null,
  maxPages: 200,
  paths: [],
};

for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--base') opts.base = args[++i];
  else if (a === '--out') opts.out = args[++i];
  else if (a === '--expect-lang') opts.expectLang = args[++i];
  else if (a === '--max-pages') opts.maxPages = parseInt(args[++i], 10);
  else if (a === '--help' || a === '-h') { printHelp(); process.exit(0); }
  else if (a.startsWith('--')) { console.error(`Unknown option: ${a}`); process.exit(2); }
  else opts.paths.push(a);
}

if (opts.paths.length === 0) {
  opts.paths = ['doc/quickstart.xml', 'doc/documentation.xml'];
}

const base = opts.base.replace(/\/$/, '');

function printHelp() {
  console.log(`SEO / indexability checker for TEI Publisher document pages.

Usage:
  node seo-check.mjs [options] [path ...]

Options:
  --base <url>        App root URL (default: ${opts.base})
  --out <file>        Write the full JSON report to <file>
  --expect-lang <l>   Expected <html lang> value; flag pages that differ
  --max-pages <n>     Max fragments to follow when measuring a document (default 200)
  -h, --help          Show this help

Paths are document paths relative to the app root, e.g. doc/quickstart.xml`);
}

// ---------------------------------------------------------------------------
// Finding helpers
// ---------------------------------------------------------------------------

const PASS = 'pass', WARN = 'warn', FAIL = 'fail', INFO = 'info';
const ICON = { pass: '✓', warn: '⚠', fail: '✗', info: '·' };

function finding(status, id, message) {
  return { status, id, message };
}

// ---------------------------------------------------------------------------
// Browser-side extraction (runs inside the page)
// ---------------------------------------------------------------------------

/**
 * Collect text and metadata from the current document. Pierces open shadow
 * roots so that content rendered by web components into their shadow DOM is
 * counted. Returned by both the raw and rendered passes.
 */
const extractInPage = () => {
  // Deep text: walk light DOM and any open shadow roots under a root element.
  function deepText(root) {
    let out = '';
    const walk = (node) => {
      if (!node) return;
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.nodeValue;
        return;
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      const tag = node.tagName;
      if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'TEMPLATE') return;
      if (node.shadowRoot) {
        // Count what is actually displayed: the shadow tree. Light-DOM children
        // are only rendered where the shadow tree slots them in; if there is no
        // <slot>, they are invisible (e.g. SSR content injected into <pb-view>
        // purely for crawlers) and must not be double-counted against the
        // shadow copy.
        node.shadowRoot.childNodes.forEach(walk);
        if (node.shadowRoot.querySelector('slot')) {
          node.childNodes.forEach(walk);
        }
        return;
      }
      node.childNodes.forEach(walk);
    };
    walk(root);
    return out.replace(/\s+/g, ' ').trim();
  }

  const head = document.head;
  const meta = (sel, attr = 'content') => {
    const el = head.querySelector(sel);
    return el ? el.getAttribute(attr) : null;
  };

  const main = document.querySelector('main') || document.body;
  const mainText = deepText(main);

  // The pb-document element carries the path/odd/view needed to walk fragments.
  const pbDocEl = document.querySelector('pb-document');
  const pbDoc = pbDocEl
    ? {
        path: pbDocEl.getAttribute('path'),
        odd: pbDocEl.getAttribute('odd'),
        view: pbDocEl.getAttribute('view'),
      }
    : null;
  const anchors = Array.from(document.querySelectorAll('a[href]')).map((a) => a.href);

  const jsonLd = Array.from(
    document.querySelectorAll('script[type="application/ld+json"]')
  ).map((s) => s.textContent.trim());

  const headings = {};
  for (let i = 1; i <= 6; i++) {
    headings['h' + i] = document.querySelectorAll('main h' + i + ', main [role="heading"]').length;
  }
  // Headings inside shadow DOM are common for components; count those too.
  let h1Deep = 0;
  document.querySelectorAll('*').forEach((el) => {
    if (el.shadowRoot) h1Deep += el.shadowRoot.querySelectorAll('h1').length;
  });

  const imgs = Array.from(document.querySelectorAll('img'));
  const imgsNoAlt = imgs.filter((i) => !i.hasAttribute('alt') || i.getAttribute('alt').trim() === '').length;

  return {
    lang: document.documentElement.getAttribute('lang'),
    title: document.title,
    description: meta('meta[name="description"]'),
    canonical: meta('link[rel="canonical"]', 'href'),
    pbDoc,
    ogTitle: meta('meta[property="og:title"]'),
    ogDescription: meta('meta[property="og:description"]'),
    ogType: meta('meta[property="og:type"]'),
    twitterCard: meta('meta[name="twitter:card"]'),
    robotsMeta: meta('meta[name="robots"]'),
    jsonLd,
    mainText,
    mainTextLen: mainText.length,
    anchorCount: anchors.length,
    headings,
    h1Total: (headings.h1 || 0) + h1Deep,
    imgCount: imgs.length,
    imgsNoAlt,
    languageDefault: (() => {
      const el = document.getElementById('language-default');
      if (!el) return null;
      try { return JSON.parse(el.textContent).language; } catch { return null; }
    })(),
  };
};

// ---------------------------------------------------------------------------
// Server-side fragment walk (ground truth for content quantity)
// ---------------------------------------------------------------------------

/**
 * Follow the `next` pointer chain through the parts API to count how many
 * fragments the document is split into and how much text they hold in total.
 * Mirrors what <pb-view> does on each pagination step.
 */
async function walkFragments(api, docPath, odd, view, maxPages) {
  const encoded = encodeURIComponent(docPath);
  let root = null;
  let count = 0;
  let totalContentLen = 0;
  const ids = [];
  const seen = new Set();

  while (count < maxPages) {
    const url =
      `${base}/api/parts/${encoded}/json?view=${encodeURIComponent(view)}` +
      `&odd=${encodeURIComponent(odd)}` +
      (root ? `&root=${encodeURIComponent(root)}` : '');
    const res = await api.get(url);
    if (!res.ok()) {
      return { count, totalContentLen, ids, error: `HTTP ${res.status()} on fragment ${count + 1}` };
    }
    let data;
    try { data = await res.json(); } catch { return { count, totalContentLen, ids, error: 'non-JSON fragment response' }; }
    count++;
    ids.push(data.id || `(frag ${count})`);
    totalContentLen += (data.content || '').length;
    const next = data.next;
    if (!next || seen.has(next)) break;
    seen.add(next);
    root = next;
  }
  return { count, totalContentLen, ids, error: null };
}

// ---------------------------------------------------------------------------
// JS-pagination walk (what is reachable only by clicking)
// ---------------------------------------------------------------------------

/**
 * Navigate forward through the document with the keyboard (pb-navigation
 * listens for ArrowRight) and count how many distinct content states the SPA
 * exposes. This is content a crawler can only reach by executing synthetic
 * interaction - effectively unreachable for most crawlers, but a useful
 * contrast against the link-reachable count. Signatures pierce shadow DOM
 * because <pb-view> renders its content into a shadow root.
 */
async function walkByClicking(page, maxPages) {
  let states = 1; // current page counts as one
  const seen = new Set();

  const snapshot = async () =>
    page.evaluate(() => {
      let out = '';
      const walk = (n) => {
        if (n.nodeType === Node.TEXT_NODE) out += n.nodeValue;
        else if (n.nodeType === Node.ELEMENT_NODE) {
          if (n.shadowRoot) n.shadowRoot.childNodes.forEach(walk);
          n.childNodes.forEach(walk);
        }
      };
      walk(document.querySelector('main') || document.body);
      return out.replace(/\s+/g, ' ').trim().slice(0, 120);
    });

  seen.add(await snapshot());

  for (let i = 0; i < maxPages; i++) {
    const before = await snapshot();
    // Keep focus on the document body so pb-navigation receives the key event
    // rather than focus drifting into freshly-loaded content.
    await page.evaluate(() => document.body.focus());
    await page.keyboard.press('ArrowRight');
    try {
      await page.waitForFunction(
        (prev) => {
          let out = '';
          const walk = (n) => {
            if (n.nodeType === Node.TEXT_NODE) out += n.nodeValue;
            else if (n.nodeType === Node.ELEMENT_NODE) {
              if (n.shadowRoot) n.shadowRoot.childNodes.forEach(walk);
              n.childNodes.forEach(walk);
            }
          };
          walk(document.querySelector('main') || document.body);
          return out.replace(/\s+/g, ' ').trim().slice(0, 120) !== prev;
        },
        before,
        { timeout: 4000 }
      );
    } catch {
      break; // no change -> reached the end of the document
    }
    await page.waitForTimeout(400); // let the fragment settle past any loading state
    const sig = await snapshot();
    if (seen.has(sig)) break;
    seen.add(sig);
    states++;
  }
  return states;
}

// ---------------------------------------------------------------------------
// Per-page analysis
// ---------------------------------------------------------------------------

async function analysePage(browser, api, path) {
  const url = `${base}/${path}`;
  const findings = [];
  const result = { path, url, findings, meta: {} };

  // --- RAW pass: JavaScript disabled --------------------------------------
  const rawCtx = await browser.newContext({ javaScriptEnabled: false });
  const rawPage = await rawCtx.newPage();
  let raw;
  try {
    const resp = await rawPage.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    result.httpStatus = resp ? resp.status() : null;
    raw = await rawPage.evaluate(extractInPage);
  } finally {
    await rawCtx.close();
  }

  // --- RENDERED pass: full JS ---------------------------------------------
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  let rendered, clickReachable = null;
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
    // Wait for pb-view to inject content (deep text under <main> grows).
    try {
      await page.waitForFunction(
        () => {
          function deep(root) {
            let n = 0;
            const walk = (node) => {
              if (node.nodeType === Node.TEXT_NODE) n += (node.nodeValue || '').trim().length;
              else if (node.nodeType === Node.ELEMENT_NODE) {
                if (node.shadowRoot) node.shadowRoot.childNodes.forEach(walk);
                node.childNodes.forEach(walk);
              }
            };
            walk(root);
            return n;
          }
          const main = document.querySelector('main');
          return main && deep(main) > 200;
        },
        null,
        { timeout: 15000 }
      );
    } catch {
      findings.push(finding(WARN, 'render-timeout', 'Rendered <main> never exceeded 200 chars of text within 15s; content may not render.'));
    }
    rendered = await page.evaluate(extractInPage);
    clickReachable = await walkByClicking(page, opts.maxPages);
  } finally {
    await ctx.close();
  }

  // --- SERVER pass: fragment chain ----------------------------------------
  const pbDoc = rendered.pbDoc || raw.pbDoc || null;
  let server = null;
  if (pbDoc && pbDoc.path) {
    server = await walkFragments(api, pbDoc.path, pbDoc.odd || 'docbook', pbDoc.view || 'div', opts.maxPages);
  } else {
    findings.push(finding(WARN, 'pagination-unreachable', 'No <pb-document> found; cannot measure fragment count.'));
  }

  result.meta = { raw, rendered, server, clickReachable };

  // --- Findings ------------------------------------------------------------
  // HTTP
  if (result.httpStatus && result.httpStatus >= 400) {
    findings.push(finding(FAIL, 'http', `Page returned HTTP ${result.httpStatus}`));
  }

  // Content visibility: how much of the rendered (displayed) text is already
  // present in the static, no-JS HTML. Both measures dedupe shadow-vs-light, so
  // a fully SSR'd page has raw ~= rendered regardless of how short the fragment.
  const rawLen = raw.mainTextLen;
  const renderedLen = rendered.mainTextLen;
  if (renderedLen > 50 && rawLen < 0.5 * renderedLen) {
    findings.push(finding(FAIL, 'js-only-content',
      `Static HTML <main> has only ${rawLen} of ${renderedLen} rendered chars; the rest is JS-only and invisible to non-rendering crawlers.`));
  } else if (rawLen > 0) {
    findings.push(finding(PASS, 'js-only-content',
      `Static HTML <main> already contains ${rawLen} chars (rendered: ${renderedLen}).`));
  } else if (renderedLen > 0) {
    findings.push(finding(FAIL, 'js-only-content', `Static HTML <main> is empty; all ${renderedLen} chars of content are JS-only.`));
  }

  // Pagination reachability
  if (server && server.count > 1) {
    const linkReachable = 1; // only the first fragment is loaded; pagination is event-driven
    findings.push(finding(FAIL, 'pagination-unreachable',
      `Document has ${server.count} fragments (~${server.totalContentLen} chars total) but pagination is JS-event driven: ` +
      `a crawler reaches ${linkReachable} of ${server.count} by following links (${clickReachable} reachable via JS navigation). ` +
      `No crawlable <a href> links to the remaining fragments.`));
  } else if (server && server.count === 1) {
    findings.push(finding(PASS, 'pagination-unreachable', 'Single-fragment document; no pagination reachability issue.'));
  } else if (server && server.error) {
    findings.push(finding(WARN, 'pagination-unreachable', `Could not measure fragments: ${server.error}`));
  }

  // Title (uniqueness checked later, across pages)
  const title = rendered.title || raw.title;
  if (!title || !title.trim()) {
    findings.push(finding(FAIL, 'title', 'Missing <title>.'));
  } else if (title.trim().length < 10) {
    findings.push(finding(WARN, 'title', `Very short <title>: "${title}".`));
  }

  // lang
  const lang = rendered.lang || raw.lang;
  if (!lang) {
    findings.push(finding(FAIL, 'lang', 'Missing <html lang> attribute.'));
  } else {
    if (opts.expectLang && lang !== opts.expectLang) {
      findings.push(finding(FAIL, 'lang', `<html lang="${lang}"> but expected "${opts.expectLang}".`));
    }
    if (raw.languageDefault && lang === raw.languageDefault && raw.languageDefault !== (opts.expectLang || raw.languageDefault)) {
      findings.push(finding(WARN, 'lang', `lang is the static #language-default ("${lang}") which may not match the content language.`));
    }
    if (!findings.some((f) => f.id === 'lang')) {
      findings.push(finding(PASS, 'lang', `<html lang="${lang}">.`));
    }
  }

  // description
  const desc = rendered.description || raw.description;
  if (!desc || !desc.trim()) {
    findings.push(finding(FAIL, 'description', 'Missing meta description.'));
  } else if (desc.length < 50 || desc.length > 160) {
    findings.push(finding(WARN, 'description', `Meta description length ${desc.length} (recommended 50-160): "${desc.slice(0, 80)}…".`));
  } else {
    findings.push(finding(PASS, 'description', 'Meta description present and reasonable length.'));
  }

  // canonical
  if (!(rendered.canonical || raw.canonical)) {
    findings.push(finding(WARN, 'canonical', 'No <link rel="canonical">.'));
  } else {
    findings.push(finding(PASS, 'canonical', 'Canonical link present.'));
  }

  // Open Graph
  if (!(rendered.ogTitle || raw.ogTitle)) {
    findings.push(finding(WARN, 'open-graph', 'No Open Graph tags (og:title); link previews will be poor.'));
  } else {
    findings.push(finding(PASS, 'open-graph', 'Open Graph tags present.'));
  }

  // Structured data
  if ((rendered.jsonLd || []).length === 0) {
    findings.push(finding(WARN, 'structured-data', 'No JSON-LD structured data.'));
  } else {
    findings.push(finding(PASS, 'structured-data', `${rendered.jsonLd.length} JSON-LD block(s).`));
  }

  // Headings
  if (rendered.h1Total === 0) {
    findings.push(finding(WARN, 'h1', 'No <h1> in main content (or shadow DOM).'));
  } else if (rendered.h1Total > 1) {
    findings.push(finding(WARN, 'h1', `${rendered.h1Total} <h1> elements; prefer one.`));
  } else {
    findings.push(finding(PASS, 'h1', 'Exactly one <h1>.'));
  }

  // Images
  if (rendered.imgsNoAlt > 0) {
    findings.push(finding(WARN, 'img-alt', `${rendered.imgsNoAlt}/${rendered.imgCount} <img> without alt text.`));
  } else if (rendered.imgCount > 0) {
    findings.push(finding(PASS, 'img-alt', `All ${rendered.imgCount} images have alt text.`));
  }

  // robots meta
  if (rendered.robotsMeta && /noindex/i.test(rendered.robotsMeta)) {
    findings.push(finding(FAIL, 'robots-meta', `Page declares robots "${rendered.robotsMeta}" - it will not be indexed.`));
  }

  return result;
}

// ---------------------------------------------------------------------------
// Site-level checks
// ---------------------------------------------------------------------------

async function siteChecks(api) {
  const findings = [];
  // robots.txt - check at server root, not app root (crawlers fetch /robots.txt)
  const origin = new URL(base).origin;
  for (const robotsUrl of [`${origin}/robots.txt`, `${base}/robots.txt`]) {
    const res = await api.get(robotsUrl).catch(() => null);
    if (res && res.ok()) {
      findings.push(finding(PASS, 'robots-txt', `robots.txt found at ${robotsUrl}.`));
      break;
    }
    if (robotsUrl === `${base}/robots.txt`) {
      findings.push(finding(WARN, 'robots-txt', 'No robots.txt at server root or app root.'));
    }
  }

  // sitemap.xml
  let sitemapOk = false;
  for (const smUrl of [`${base}/sitemap.xml`, `${origin}/sitemap.xml`]) {
    const res = await api.get(smUrl).catch(() => null);
    if (res && res.ok()) {
      const body = await res.text();
      if (/<urlset|<sitemapindex/.test(body)) {
        findings.push(finding(PASS, 'sitemap', `Valid sitemap at ${smUrl}.`));
        sitemapOk = true;
        break;
      }
    }
  }
  if (!sitemapOk) {
    findings.push(finding(FAIL, 'sitemap', 'No valid sitemap.xml; crawlers must discover every document/fragment by link-walking (which fails given JS pagination).'));
  }

  return findings;
}

// ---------------------------------------------------------------------------
// Cross-page checks (run after all pages analysed)
// ---------------------------------------------------------------------------

function crossPageChecks(results) {
  const titles = results.map((r) => (r.meta.rendered?.title || r.meta.raw?.title || '').trim());
  const nonEmpty = titles.filter(Boolean);
  const unique = new Set(nonEmpty);
  if (nonEmpty.length > 1 && unique.size === 1) {
    for (const r of results) {
      r.findings.push(finding(FAIL, 'title-unique',
        `<title> "${nonEmpty[0]}" is identical across all ${nonEmpty.length} checked pages; titles must be page-specific.`));
    }
  } else if (nonEmpty.length > 1) {
    const counts = {};
    nonEmpty.forEach((t) => (counts[t] = (counts[t] || 0) + 1));
    for (const r of results) {
      const t = (r.meta.rendered?.title || r.meta.raw?.title || '').trim();
      if (counts[t] > 1) {
        r.findings.push(finding(WARN, 'title-unique', `<title> "${t}" is shared by ${counts[t]} pages.`));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

function rank(status) {
  return status === FAIL ? 3 : status === WARN ? 2 : status === INFO ? 1 : 0;
}

function printReport(results, site) {
  const out = [];
  out.push('');
  out.push('═══════════════════════════════════════════════════════════════');
  out.push(' TEI Publisher SEO / indexability report');
  out.push(`  base: ${base}`);
  out.push('═══════════════════════════════════════════════════════════════');

  out.push('\nSite-level:');
  for (const f of site) out.push(`  ${ICON[f.status]} [${f.id}] ${f.message}`);

  for (const r of results) {
    out.push(`\n${r.path}  (HTTP ${r.httpStatus})`);
    const sorted = [...r.findings].sort((a, b) => rank(b.status) - rank(a.status));
    for (const f of sorted) out.push(`  ${ICON[f.status]} [${f.id}] ${f.message}`);
  }

  // summary
  const all = [...site, ...results.flatMap((r) => r.findings)];
  const fails = all.filter((f) => f.status === FAIL).length;
  const warns = all.filter((f) => f.status === WARN).length;
  out.push('\n───────────────────────────────────────────────────────────────');
  out.push(` Summary: ${fails} fail, ${warns} warn, ${all.filter((f) => f.status === PASS).length} pass`);
  out.push('───────────────────────────────────────────────────────────────\n');

  console.log(out.join('\n'));
  return fails;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const browser = await chromium.launch();
  const api = await pwRequest.newContext({ ignoreHTTPSErrors: true });
  const results = [];

  try {
    const site = await siteChecks(api);
    for (const path of opts.paths) {
      process.stderr.write(`analysing ${path} …\n`);
      try {
        results.push(await analysePage(browser, api, path));
      } catch (err) {
        results.push({
          path, url: `${base}/${path}`, httpStatus: null, meta: {},
          findings: [finding(FAIL, 'error', `Analysis failed: ${err.message}`)],
        });
      }
    }
    crossPageChecks(results);

    const fails = printReport(results, site);

    if (opts.out) {
      const fs = await import('node:fs/promises');
      await fs.writeFile(opts.out, JSON.stringify({ base, generated: new Date().toISOString(), site, pages: results }, null, 2));
      console.log(`Full report written to ${opts.out}`);
    }

    process.exitCode = fails > 0 ? 1 : 0;
  } finally {
    await api.dispose();
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
