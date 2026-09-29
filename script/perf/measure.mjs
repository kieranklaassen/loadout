#!/usr/bin/env node
// Page-load timing for the optimize/ssr-and-page-speed run. Prints one JSON object to stdout
// (logs go to stderr) with the metrics named in the run's spec.
//
// What it does, in order:
//   1. Builds the frontend the way the Dockerfile does (`bin/rails assets:precompile`, clean).
//   2. Makes a throwaway production database from the demo seeds, and one signed-in session.
//   3. Starts the app through the real container start path
//      (`bin/docker-entrypoint ./bin/thrust ./bin/rails server`), so anything the repo adds
//      there (for example a Node render server) runs exactly as it would in production.
//   4. Loads each page in a fresh headless Chrome profile, throttled like a mid-tier phone,
//      and records paint times, transfer sizes and errors. Pages are visited round-robin so
//      machine drift hits every page equally.
//   5. Fetches each page's raw HTML (no JavaScript) to see whether the content arrives
//      server-rendered.
//
// Environment: PERF_RUNS (loads per page, default 5), CHROME_BIN, PERF_KEEP=1 (leave the
// stack running is not supported; it only keeps the temp directory and logs).

import { spawn, spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import net from 'node:net'
import os from 'node:os'
import path from 'node:path'

const ROOT = path.resolve(import.meta.dirname, '../..')
const RUNS = Number(process.env.PERF_RUNS ?? 5)
const CPU_SLOWDOWN = 4
const LATENCY_MS = 150
const DOWN_BYTES_PER_S = (9 * 1000 * 1000) / 8 // 9 Mbps
const UP_BYTES_PER_S = (1.5 * 1000 * 1000) / 8
const VIEWPORT = { width: 412, height: 915, deviceScaleFactor: 2, mobile: true }
const LOAD_CAP_MS = 45_000
const IDLE_MS = 750

// Each page: what must be visible (case-insensitive) once loaded, and in the raw server HTML
// for the page to count as server-rendered.
const PAGES = [
  { key: 'home_out', metric: 'lcp_home_out_ms', path: '/', auth: false, landmarks: ['the ai tools', 'latest model launches', 'what we use'] },
  { key: 'kind', metric: 'lcp_kind_ms', path: '/kinds/coding', auth: false, landmarks: ['coding', 'what we use', 'use it'] },
  { key: 'profile', metric: 'lcp_profile_ms', path: '/kieran', auth: false, landmarks: ['kieran klaassen', 'ranked'] },
  { key: 'signin', metric: 'lcp_signin_ms', path: '/session/new', auth: false, landmarks: ['sign in with every'] },
  { key: 'home_in', metric: 'lcp_home_in_ms', path: '/', auth: true, landmarks: ['the ai tools', 'you share with anyone with the link'] },
  { key: 'editor', metric: 'lcp_editor_ms', path: '/toolbox/edit?kind=coding', auth: true, landmarks: ['rank your tools', 'coding', 'confirmed'] },
]

const log = (...args) => console.error('[perf]', ...args)
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b)
  const mid = sorted.length >> 1
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}
const mean = (values) => values.reduce((sum, value) => sum + value, 0) / values.length
const round = (value, digits = 1) => Math.round(value * 10 ** digits) / 10 ** digits

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.once('error', reject)
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address()
      server.close(() => resolve(port))
    })
  })
}

const children = []
function start(command, args, options = {}) {
  const child = spawn(command, args, { cwd: ROOT, detached: true, stdio: ['ignore', 'pipe', 'pipe'], ...options })
  children.push(child)
  return child
}
function killAll() {
  for (const child of children) {
    try {
      process.kill(-child.pid, 'SIGTERM')
    } catch {}
  }
  setTimeout(() => {
    for (const child of children) {
      try {
        process.kill(-child.pid, 'SIGKILL')
      } catch {}
    }
  }, 3000).unref()
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...options })
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed (${result.status}):\n${(result.stdout ?? '').slice(-2000)}\n${(result.stderr ?? '').slice(-2000)}`)
  }
  return result.stdout
}

function chromePath() {
  const candidates = [
    process.env.CHROME_BIN,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean)
  const found = candidates.find((candidate) => existsSync(candidate))
  if (!found) throw new Error('No Chrome found. Set CHROME_BIN.')
  return found
}

// --- Minimal Chrome DevTools Protocol client (Node 22 ships WebSocket) -------------------
class CDP {
  constructor(url) {
    this.ws = new WebSocket(url)
    this.nextId = 1
    this.pending = new Map()
    this.listeners = new Map()
    this.ready = new Promise((resolve, reject) => {
      this.ws.addEventListener('open', resolve, { once: true })
      this.ws.addEventListener('error', () => reject(new Error('DevTools connection failed')), { once: true })
    })
    this.ws.addEventListener('message', ({ data }) => {
      const message = JSON.parse(data)
      if (message.id) {
        const entry = this.pending.get(message.id)
        if (!entry) return
        this.pending.delete(message.id)
        message.error ? entry.reject(new Error(`${entry.method}: ${message.error.message}`)) : entry.resolve(message.result)
      } else {
        for (const listener of this.listeners.get(message.sessionId ?? '') ?? []) listener(message.method, message.params)
      }
    })
  }
  send(method, params = {}, sessionId) {
    const id = this.nextId++
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method })
      this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }))
    })
  }
  on(sessionId, listener) {
    const list = this.listeners.get(sessionId) ?? []
    list.push(listener)
    this.listeners.set(sessionId, list)
  }
  close() {
    try {
      this.ws.close()
    } catch {}
  }
}

async function waitFor(check, { timeoutMs, everyMs = 250, what }) {
  const deadline = Date.now() + timeoutMs
  for (;;) {
    try {
      const value = await check()
      if (value) return value
    } catch {}
    if (Date.now() > deadline) throw new Error(`Timed out waiting for ${what}`)
    await sleep(everyMs)
  }
}

// --- Page helpers -----------------------------------------------------------------------
const LCP_OBSERVER = `
  window.__lcp = 0;
  try {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        window.__lcp = entry.startTime;
        window.__lcpInfo = { tag: entry.element ? entry.element.tagName : '', url: entry.url || '', size: entry.size, id: entry.id || '' };
      }
    }).observe({ type: 'largest-contentful-paint', buffered: true });
  } catch (e) {}
`

const normalize = (text) => text.toLowerCase().replace(/\s+/g, ' ')

// The visible text inside the #app element of the raw HTML, scripts and tags removed.
function appText(html) {
  const start = html.search(/<div[^>]*\bid="app"/)
  if (start < 0) return ''
  let rest = html.slice(start)
  const end = rest.indexOf('</body>')
  if (end > 0) rest = rest.slice(0, end)
  return normalize(
    rest
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/&quot;/g, '"'),
  )
}

async function loadPage(cdp, base, page, cookie) {
  const { browserContextId } = await cdp.send('Target.createBrowserContext', { disposeOnDetach: true })
  const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank', browserContextId })
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true })
  const s = (method, params) => cdp.send(method, params, sessionId)

  const requests = new Map()
  let inflight = 0
  let lastActivity = Date.now()
  let loaded = false
  let mainStatus = 0
  const errors = []
  let hydrationErrors = 0

  cdp.on(sessionId, (method, p) => {
    if (method === 'Network.requestWillBeSent' && !p.request.url.startsWith('data:')) {
      inflight += 1
      lastActivity = Date.now()
      requests.set(p.requestId, { type: p.type, url: p.request.url, bytes: 0, start: p.timestamp })
    } else if (method === 'Network.responseReceived') {
      const entry = requests.get(p.requestId)
      if (entry) {
        entry.status = p.response.status
        entry.mime = p.response.mimeType
        if (p.type === 'Document' && p.response.url.split('#')[0] === `${base}${page.path}`) mainStatus = p.response.status
        if (p.response.status >= 400) errors.push(`HTTP ${p.response.status} ${p.response.url}`)
      }
    } else if (method === 'Network.loadingFinished') {
      const entry = requests.get(p.requestId)
      if (entry) {
        entry.bytes = p.encodedDataLength
        entry.end = p.timestamp
      }
      inflight = Math.max(0, inflight - 1)
      lastActivity = Date.now()
    } else if (method === 'Network.loadingFailed') {
      inflight = Math.max(0, inflight - 1)
      lastActivity = Date.now()
      if (!p.canceled) errors.push(`request failed: ${p.errorText} ${requests.get(p.requestId)?.url ?? ''}`)
    } else if (method === 'Page.loadEventFired') {
      loaded = true
      lastActivity = Date.now()
    } else if (method === 'Runtime.exceptionThrown') {
      const text = p.exceptionDetails.exception?.description ?? p.exceptionDetails.text
      errors.push(`exception: ${String(text).slice(0, 300)}`)
      if (/hydrat|did not match|server.rendered/i.test(String(text))) hydrationErrors += 1
    } else if (method === 'Runtime.consoleAPICalled' && p.type === 'error') {
      const text = p.args.map((arg) => arg.value ?? arg.description ?? '').join(' ')
      errors.push(`console.error: ${text.slice(0, 300)}`)
      if (/hydrat|did not match|server.rendered/i.test(text)) hydrationErrors += 1
    }
  })

  await Promise.all([s('Page.enable'), s('Network.enable'), s('Runtime.enable')])
  await s('Emulation.setDeviceMetricsOverride', VIEWPORT)
  await s('Emulation.setCPUThrottlingRate', { rate: CPU_SLOWDOWN })
  await s('Network.emulateNetworkConditions', { offline: false, latency: LATENCY_MS, downloadThroughput: DOWN_BYTES_PER_S, uploadThroughput: UP_BYTES_PER_S })
  if (cookie) await s('Network.setCookie', { name: 'session_id', value: cookie, url: base, httpOnly: true })
  await s('Page.addScriptToEvaluateOnNewDocument', { source: LCP_OBSERVER })
  await s('Page.navigate', { url: `${base}${page.path}` })

  const started = Date.now()
  await waitFor(() => loaded, { timeoutMs: LOAD_CAP_MS, everyMs: 50, what: `load of ${page.path}` })
  await waitFor(() => inflight === 0 && Date.now() - lastActivity >= IDLE_MS, { timeoutMs: Math.max(1000, LOAD_CAP_MS - (Date.now() - started)), everyMs: 50, what: `network idle on ${page.path}` })

  const evaluate = async (expression) => (await s('Runtime.evaluate', { expression, returnByValue: true })).result.value
  const timing = await evaluate(`(() => {
    const nav = performance.getEntriesByType('navigation')[0];
    const fcp = performance.getEntriesByName('first-contentful-paint')[0];
    return { ttfb: nav ? nav.responseStart : 0, fcp: fcp ? fcp.startTime : 0, lcp: window.__lcp || 0, lcpInfo: window.__lcpInfo || null };
  })()`)
  const text = normalize((await evaluate('document.body.innerText')) ?? '')
  const missingList = page.landmarks.filter((landmark) => !text.includes(landmark))
  const missing = missingList.length
  if (missing) errors.push(`missing on ${page.path}: ${missingList.join(', ')}`)

  const sum = (types) => [...requests.values()].filter((r) => types.includes(r.type)).reduce((total, r) => total + r.bytes, 0) / 1024
  const all = [...requests.values()]
  const result = {
    lcp: timing.lcp || timing.fcp,
    fcp: timing.fcp,
    ttfb: timing.ttfb,
    jsKb: sum(['Script']),
    cssKb: sum(['Stylesheet']),
    fontKb: sum(['Font']),
    totalKb: all.reduce((total, r) => total + r.bytes, 0) / 1024,
    requests: all.length,
    status: mainStatus,
    missing,
    hydrationErrors,
    errors,
    noLcp: timing.lcp === 0,
    lcpInfo: timing.lcpInfo,
    waterfall: process.env.PERF_WATERFALL ? all.map((r) => ({ type: r.type, url: r.url.replace(base, ''), kb: Math.round(r.bytes / 102.4) / 10, start: Math.round(((r.start ?? 0) - (all[0]?.start ?? 0)) * 1000), end: Math.round(((r.end ?? r.start ?? 0) - (all[0]?.start ?? 0)) * 1000) })) : undefined,
  }
  await cdp.send('Target.closeTarget', { targetId }).catch(() => {})
  await cdp.send('Target.disposeBrowserContext', { browserContextId }).catch(() => {})
  return result
}

async function fetchHtml(base, page, cookie) {
  const response = await fetch(`${base}${page.path}`, { headers: cookie ? { cookie: `session_id=${cookie}` } : {}, redirect: 'manual' })
  return { status: response.status, headers: response.headers, html: await response.text() }
}

async function main() {
  const tmp = mkdtempSync(path.join(os.tmpdir(), 'perf-'))
  const started = Date.now()
  const [rails, front] = [await freePort(), await freePort()]
  const base = `http://localhost:${front}`
  const dbPath = path.join(tmp, 'production.sqlite3')
  const env = {
    ...process.env,
    RAILS_ENV: 'production',
    SECRET_KEY_BASE: 'perf-harness-secret-key-base-perf-harness-secret-key-base-1234567890',
    PUBLIC_BASE_URL: base,
    DATABASE_URL: `sqlite3:${dbPath}`,
    RAILS_LOG_LEVEL: 'warn',
    RAILS_LOG_TO_STDOUT: '1',
    WEB_CONCURRENCY: '1',
    RAILS_MAX_THREADS: '3',
    HTTP_PORT: String(front),
    TARGET_PORT: String(rails),
    PORT: String(rails),
    FONTCONFIG_PATH: process.env.FONTCONFIG_PATH ?? '',
  }
  delete env.SOLID_QUEUE_IN_PUMA

  try {
    log('building frontend the way the Dockerfile does')
    for (const dir of ['public/vite', 'public/vite-ssr', 'public/vite-dev', 'public/assets']) rmSync(path.join(ROOT, dir), { recursive: true, force: true })
    run('bin/rails', ['assets:precompile'], { env: { ...env, SECRET_KEY_BASE_DUMMY: '1' } })

    log('preparing a throwaway production database with demo members')
    run('bin/rails', ['db:prepare'], { env })
    run('bin/rails', ['runner', 'Catalog::Sync.call; load Rails.root.join("db/seeds/development.rb").to_s'], { env })
    const cookie = run('bin/rails', ['runner', 'script/perf/session_cookie.rb'], { env }).trim().split('\n').pop()

    log(`starting the app on :${front} (rails :${rails})`)
    const server = start('bin/docker-entrypoint', ['./bin/thrust', './bin/rails', 'server'], { env })
    const serverLog = []
    for (const stream of [server.stdout, server.stderr]) stream.on('data', (chunk) => serverLog.push(String(chunk)))
    let exited = false
    server.on('exit', () => (exited = true))
    await waitFor(async () => !exited && (await fetch(`http://localhost:${front}/up`)).ok, { timeoutMs: 120_000, everyMs: 500, what: 'the app to answer /up' }).catch((error) => {
      throw new Error(`${error.message}\n--- server output ---\n${serverLog.join('').slice(-3000)}`)
    })

    log('warming up')
    await sleep(3000)
    for (let round = 0; round < 3; round += 1) {
      for (const page of PAGES) await fetchHtml(base, page, page.auth ? cookie : null).catch(() => {})
    }

    // Server-rendered content: the raw HTML, no JavaScript.
    const ssr = {}
    for (const page of PAGES) {
      const { status, html } = await fetchHtml(base, page, page.auth ? cookie : null)
      const text = appText(html)
      ssr[page.key] = status === 200 && page.landmarks.every((landmark) => text.includes(landmark))
    }

    // Privacy: what one viewer gets must never be served to another.
    const cacheFlags = []
    for (const page of PAGES.filter((p) => p.auth)) {
      const { headers } = await fetchHtml(base, page, cookie)
      const control = headers.get('cache-control') ?? ''
      cacheFlags.push(!/(^|,)\s*public\b|s-maxage/i.test(control))
    }
    const viewerProps = (html) => /("|&quot;)current_user("|&quot;):\s*\{/.test(html)
    const signedInHome = (await fetchHtml(base, PAGES[4], cookie)).html
    const anonymousHome = (await fetchHtml(base, PAGES[0], null)).html
    const signedInAgain = (await fetchHtml(base, PAGES[4], cookie)).html
    const privateCacheOk = cacheFlags.every(Boolean) && viewerProps(signedInHome) && !viewerProps(anonymousHome) && viewerProps(signedInAgain)

    log('launching Chrome')
    const debugPort = await freePort()
    const chrome = start(chromePath(), [
      '--headless=new',
      `--remote-debugging-port=${debugPort}`,
      `--user-data-dir=${path.join(tmp, 'chrome')}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-component-update',
      '--disable-sync',
      '--mute-audio',
      'about:blank',
    ])
    chrome.stderr.on('data', () => {})
    const version = await waitFor(async () => (await fetch(`http://127.0.0.1:${debugPort}/json/version`)).json(), { timeoutMs: 30_000, what: 'Chrome DevTools' })
    const cdp = new CDP(version.webSocketDebuggerUrl)
    await cdp.ready

    log(`measuring ${PAGES.length} pages x ${RUNS} runs`)
    const samples = Object.fromEntries(PAGES.map((page) => [page.key, []]))
    for (let run = 0; run < RUNS; run += 1) {
      for (const page of PAGES) {
        try {
          samples[page.key].push(await loadPage(cdp, base, page, page.auth ? cookie : null))
        } catch (error) {
          log(`load failed for ${page.path}: ${error.message}`)
          samples[page.key].push({ failed: true, error: error.message })
        }
      }
    }
    cdp.close()
    if (process.env.PERF_WATERFALL) {
      for (const page of PAGES) {
        const sample = samples[page.key].find((entry) => !entry.failed)
        if (!sample) continue
        log(`waterfall ${page.path} (lcp ${Math.round(sample.lcp)} ms, fcp ${Math.round(sample.fcp)} ms, ttfb ${Math.round(sample.ttfb)} ms) lcp element: ${JSON.stringify(sample.lcpInfo)}`)
        for (const r of sample.waterfall) log(`  ${String(r.start).padStart(5)}-${String(r.end).padStart(5)} ms ${r.type.padEnd(10)} ${String(r.kb).padStart(6)} KB ${r.url.slice(0, 90)}`)
      }
    }

    const good = (key) => samples[key].filter((sample) => !sample.failed)
    const perPage = (key, field) => (good(key).length ? median(good(key).map((sample) => sample[field])) : NaN)
    const pageMedians = (field) => PAGES.map((page) => perPage(page.key, field))
    const allSamples = Object.values(samples).flat()
    const allErrors = allSamples.flatMap((sample) => (sample.failed ? [`load failed: ${sample.error}`] : sample.errors))
    if (allErrors.length) log(`errors seen (${allErrors.length}), first ones:\n  ${[...new Set(allErrors)].slice(0, 8).join('\n  ')}`)

    const result = {
      lcp_ms: round(mean(pageMedians('lcp'))),
      fcp_ms: round(mean(pageMedians('fcp'))),
      ttfb_ms: round(mean(pageMedians('ttfb'))),
      js_kb: round(mean(pageMedians('jsKb'))),
      css_kb: round(mean(pageMedians('cssKb'))),
      font_kb: round(mean(pageMedians('fontKb'))),
      total_kb: round(mean(pageMedians('totalKb'))),
      requests: round(mean(pageMedians('requests'))),
      ssr_pages: Object.values(ssr).filter(Boolean).length,
      pages_ok: PAGES.filter((page) => good(page.key).length === RUNS && good(page.key).every((sample) => sample.status === 200)).length,
      hydration_errors: allSamples.reduce((total, sample) => total + (sample.hydrationErrors ?? 0), 0),
      console_errors: allErrors.length,
      content_missing: allSamples.reduce((total, sample) => total + (sample.missing ?? 0), 0),
      private_cache_ok: privateCacheOk ? 1 : 0,
      ...Object.fromEntries(PAGES.map((page) => [page.metric, round(perPage(page.key, 'lcp'))])),
    }
    log(`done in ${Math.round((Date.now() - started) / 1000)}s; ssr: ${JSON.stringify(ssr)}`)
    process.stdout.write(`${JSON.stringify(result)}\n`)
  } finally {
    killAll()
    await sleep(500)
    if (!process.env.PERF_KEEP) rmSync(tmp, { recursive: true, force: true })
  }
}

main().then(
  () => process.exit(0),
  (error) => {
    console.error(`[perf] FAILED: ${error.stack ?? error}`)
    killAll()
    process.exit(1)
  },
)
