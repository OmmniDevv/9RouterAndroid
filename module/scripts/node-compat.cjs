'use strict';
// 9RouterAndroid — node-compat.cjs
// Preloaded into every Node process through NODE_OPTIONS=--require=...
//
//  1. The glibc loader is /proc/self/exe on Android, so child Node processes
//     must re-enter our wrapper instead of executing the loader directly.
//  2. os.networkInterfaces()/os.userInfo() throw on some Android builds
//     (netlink EACCES, no /etc/passwd). Make them non-fatal.
//  3. glibc has no /etc/resolv.conf on Android, so getaddrinfo() cannot see
//     the phone's DNS. Resolve names over DNS-over-HTTPS (to literal IPs, so
//     there is no chicken-and-egg) and fall back to the stock resolver.
//
// Env:  ROUTERANDROID_NODE       path of the wrapper (sets process.execPath)
//       ROUTERANDROID_DOH        auto (default) | off
//       ROUTERANDROID_DOH_URLS   comma separated JSON-DoH endpoints (override)

if (process.env.ROUTERANDROID_NODE) {
  try { process.execPath = process.env.ROUTERANDROID_NODE; } catch (_) { /* read-only on some builds */ }
}

const os = require('os');

function guard(obj, name, fallback) {
  const orig = obj[name];
  if (typeof orig !== 'function') return;
  obj[name] = function guarded(...args) {
    try { return orig.apply(this, args); } catch (_) { return fallback(); }
  };
}
guard(os, 'networkInterfaces', () => ({}));
guard(os, 'userInfo', () => ({
  uid: 0, gid: 0, username: 'root',
  homedir: process.env.HOME || '/', shell: '/system/bin/sh',
}));

// Next.js renames the process ("next-server (vX)"), which rewrites
// /proc/PID/cmdline and defeats `pgrep -f` supervision. Keep argv intact.
try {
  const d = Object.getOwnPropertyDescriptor(process, 'title');
  if (d && d.configurable) {
    let title = process.title;
    Object.defineProperty(process, 'title', {
      configurable: true, enumerable: true,
      get() { return title; },
      set(v) { title = String(v); },
    });
  }
} catch (_) { /* leave the stock behaviour */ }

const dohMode = String(process.env.ROUTERANDROID_DOH || 'auto').toLowerCase();
if (!['off', '0', 'false', 'no'].includes(dohMode)) installDoh();

function installDoh() {
  const dns = require('dns');
  const net = require('net');
  const util = require('util');
  const http = require('http');
  const https = require('https');

  const origLookup = dns.lookup;
  const origPromisesLookup = dns.promises && dns.promises.lookup;

  const ENDPOINTS = (process.env.ROUTERANDROID_DOH_URLS
    ? process.env.ROUTERANDROID_DOH_URLS.split(',').map((s) => s.trim()).filter(Boolean)
    : [
      'https://1.1.1.1/dns-query',   // Cloudflare (JSON API)
      'https://8.8.8.8/resolve',     // Google (JSON API)
      'https://1.0.0.1/dns-query',
      'https://8.8.4.4/resolve',
    ]);
  const TIMEOUT_MS = 2000;
  const MIN_TTL = 30;
  const MAX_TTL = 300;
  const BREAKER_FAILS = 3;
  const BREAKER_MS = 5 * 60 * 1000;

  // `lookup: origLookup` keeps hostname-based custom endpoints from recursing
  // into this very patch.
  const agentOpts = { keepAlive: true, maxSockets: 4, lookup: origLookup };
  const httpsAgent = new https.Agent(agentOpts);
  const httpAgent = new http.Agent(agentOpts);

  const cache = new Map();      // "host|fam" -> { addrs, exp }
  const inflight = new Map();   // "host|fam" -> Promise<string[]>
  let consecutiveFails = 0;
  let disabledUntil = 0;

  function notFound(host) {
    const e = new Error('getaddrinfo ENOTFOUND ' + host);
    e.code = 'ENOTFOUND'; e.errno = -3008; e.syscall = 'getaddrinfo'; e.hostname = host;
    return e;
  }

  function getJson(base, name, type) {
    return new Promise((resolve, reject) => {
      const u = new URL(base);
      u.searchParams.set('name', name);
      u.searchParams.set('type', type);
      const lib = u.protocol === 'http:' ? http : https;
      const req = lib.get(u, {
        agent: u.protocol === 'http:' ? httpAgent : httpsAgent,
        headers: { accept: 'application/dns-json' },
        timeout: TIMEOUT_MS,
      }, (res) => {
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (c) => { body += c; if (body.length > 65536) req.destroy(new Error('doh: oversized reply')); });
        res.on('end', () => {
          if (res.statusCode !== 200) return reject(new Error('doh: http ' + res.statusCode));
          try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
        });
      });
      req.on('timeout', () => req.destroy(new Error('doh: timeout')));
      req.on('error', reject);
    });
  }

  async function queryOne(base, name, type) {
    const j = await getJson(base, name, type);
    if (j.Status === 3) { const e = notFound(name); e.nxdomain = true; throw e; }
    if (j.Status !== 0) throw new Error('doh: rcode ' + j.Status);
    const want = type === 'AAAA' ? 28 : 1;
    return (j.Answer || []).filter((a) => a.type === want && net.isIP(a.data)).map((a) => ({ addr: a.data, ttl: a.TTL | 0 }));
  }

  // Race two endpoints; first answer wins. NXDOMAIN is authoritative.
  function race(group, name, type) {
    return new Promise((resolve, reject) => {
      let pending = group.length;
      let lastErr;
      let done = false;
      for (const ep of group) {
        queryOne(ep, name, type).then((r) => {
          if (!done) { done = true; resolve(r); }
        }, (e) => {
          if (done) return;
          if (e && e.nxdomain) { done = true; return reject(e); }
          lastErr = e;
          if (--pending === 0) reject(lastErr);
        });
      }
    });
  }

  async function dohResolve(name, type) {
    const groups = [];
    for (let i = 0; i < ENDPOINTS.length; i += 2) groups.push(ENDPOINTS.slice(i, i + 2));
    let lastErr = new Error('doh: no endpoints');
    for (const g of groups) {
      try { return await race(g, name, type); } catch (e) { if (e && e.nxdomain) throw e; lastErr = e; }
    }
    throw lastErr;
  }

  function normFamily(f) {
    if (f === 'IPv4') return 4;
    if (f === 'IPv6') return 6;
    return f === 4 || f === 6 ? f : 0;
  }

  async function resolveHost(host, fam) {
    const key = host + '|' + fam;
    const hit = cache.get(key);
    if (hit && hit.exp > Date.now()) return hit.addrs;
    if (inflight.has(key)) return inflight.get(key);
    const p = (async () => {
      let recs = [];
      if (fam === 6) recs = await dohResolve(host, 'AAAA');
      else {
        recs = await dohResolve(host, 'A');
        if (!recs.length && fam === 0) recs = await dohResolve(host, 'AAAA');
      }
      if (!recs.length) throw notFound(host);
      const ttl = Math.min(MAX_TTL, Math.max(MIN_TTL, Math.min(...recs.map((r) => r.ttl || MIN_TTL))));
      const addrs = recs.map((r) => r.addr);
      cache.set(key, { addrs, exp: Date.now() + ttl * 1000 });
      return addrs;
    })();
    inflight.set(key, p);
    try { return await p; } finally { inflight.delete(key); }
  }

  function bypass(host) {
    return typeof host !== 'string' || host === '' || net.isIP(host) ||
      host === 'localhost' || host.endsWith('.localhost');
  }

  // Returns addrs, or null when the caller should use the stock resolver.
  async function tryDoh(host, fam) {
    if (bypass(host) || Date.now() < disabledUntil) return null;
    try {
      const addrs = await resolveHost(host, fam);
      consecutiveFails = 0;
      return addrs;
    } catch (e) {
      if (e && e.nxdomain) { consecutiveFails = 0; throw e; }
      if (e && e.code === 'ENOTFOUND') throw e;
      if (++consecutiveFails >= BREAKER_FAILS) { disabledUntil = Date.now() + BREAKER_MS; consecutiveFails = 0; }
      return null;
    }
  }

  dns.lookup = function lookup(hostname, options, callback) {
    if (typeof options === 'function') { callback = options; options = {}; }
    else if (typeof options === 'number') options = { family: options };
    options = options || {};
    if (typeof callback !== 'function' || bypass(hostname)) {
      return origLookup.call(dns, hostname, options, callback);
    }
    tryDoh(hostname, normFamily(options.family)).then((addrs) => {
      if (!addrs) return origLookup.call(dns, hostname, options, callback);
      setImmediate(() => {
        if (options.all) callback(null, addrs.map((a) => ({ address: a, family: net.isIP(a) })));
        else callback(null, addrs[0], net.isIP(addrs[0]));
      });
    }, (err) => setImmediate(() => callback(err)));
  };

  if (origPromisesLookup) {
    dns.promises.lookup = async function lookup(hostname, options) {
      if (typeof options === 'number') options = { family: options };
      options = options || {};
      if (bypass(hostname)) return origPromisesLookup.call(dns.promises, hostname, options);
      const addrs = await tryDoh(hostname, normFamily(options.family));
      if (!addrs) return origPromisesLookup.call(dns.promises, hostname, options);
      if (options.all) return addrs.map((a) => ({ address: a, family: net.isIP(a) }));
      return { address: addrs[0], family: net.isIP(addrs[0]) };
    };
  }

  // util.promisify(dns.lookup) must keep resolving to {address, family}.
  try {
    dns.lookup[util.promisify.custom] = (host, opts) => dns.promises.lookup(host, opts);
  } catch (_) { /* ignore */ }
}
