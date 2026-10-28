#!/usr/bin/env node
'use strict';
// 9RouterAndroid — helper used by bin/9router (no npm needed on device).
//
//   resolve [version|latest]              -> 3 lines: version, tarball URL, integrity
//   download <url> <dest> [integrity]     -> download + verify npm SRI hash (sha512/sha1)
//   create-key <baseUrl> <password> <name>-> login, reuse or create an API key, print it
//   models <baseUrl> [filter]             -> list model ids from /v1/models
//   dns <host>                            -> resolve through the patched resolver

const fs = require('fs');
const crypto = require('crypto');
const { Readable } = require('stream');
const { pipeline } = require('stream/promises');

const REGISTRY = (process.env.ROUTERANDROID_REGISTRY || 'https://registry.npmjs.org').replace(/\/+$/, '');
const PKG = '9router';

async function resolveRelease(spec) {
  const r = await fetch(`${REGISTRY}/${PKG}/${encodeURIComponent(spec || 'latest')}`, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(20000),
  });
  if (!r.ok) throw new Error(`registry returned HTTP ${r.status} for ${PKG}@${spec || 'latest'}`);
  const j = await r.json();
  if (!j.version || !j.dist || !j.dist.tarball) throw new Error('unexpected registry reply');
  return { version: j.version, tarball: j.dist.tarball, integrity: j.dist.integrity || '' };
}

async function download(url, dest, integrity) {
  const r = await fetch(url, { signal: AbortSignal.timeout(10 * 60 * 1000), redirect: 'follow' });
  if (!r.ok || !r.body) throw new Error(`download failed: HTTP ${r.status}`);
  let algo = null;
  let want = null;
  const m = /^(sha512|sha384|sha256|sha1)-(.+)$/.exec(integrity || '');
  if (m) { algo = m[1]; want = m[2]; }
  const hash = algo ? crypto.createHash(algo) : null;
  const out = fs.createWriteStream(dest, { mode: 0o600 });
  const src = Readable.fromWeb(r.body);
  if (hash) src.on('data', (c) => hash.update(c));
  await pipeline(src, out);
  if (hash) {
    const got = hash.digest('base64');
    if (got !== want) {
      try { fs.unlinkSync(dest); } catch (_) { /* ignore */ }
      throw new Error('integrity check FAILED (expected ' + algo + '-' + want.slice(0, 12) + '…, got ' + got.slice(0, 12) + '…)');
    }
  }
  return fs.statSync(dest).size;
}

async function jsonFetch(url, opts) {
  const r = await fetch(url, { signal: AbortSignal.timeout(15000), ...opts });
  let body = null;
  try { body = await r.json(); } catch (_) { /* not json */ }
  return { ok: r.ok, status: r.status, body, headers: r.headers };
}

async function createKey(base, password, name) {
  const login = await jsonFetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ password }),
  });
  if (!login.ok) {
    throw new Error(`dashboard login failed (HTTP ${login.status}). If you changed the password in the dashboard, pass the key yourself: --key sk-...`);
  }
  const setCookie = typeof login.headers.getSetCookie === 'function' ? login.headers.getSetCookie() : [];
  const cookie = setCookie.map((c) => c.split(';')[0]).join('; ');
  if (!cookie) throw new Error('login succeeded but no session cookie was returned');
  const auth = { cookie, 'content-type': 'application/json' };

  const list = await jsonFetch(`${base}/api/keys`, { headers: auth });
  const existing = list.ok && list.body && Array.isArray(list.body.keys)
    ? list.body.keys.find((k) => k.name === name && k.isActive !== false && typeof k.key === 'string')
    : null;
  if (existing) return existing.key;

  const made = await jsonFetch(`${base}/api/keys`, { method: 'POST', headers: auth, body: JSON.stringify({ name }) });
  if (!made.ok || !made.body || !made.body.key) throw new Error(`could not create API key (HTTP ${made.status})`);
  return made.body.key;
}

async function models(base, filter) {
  const headers = process.env.ROUTERANDROID_KEY ? { authorization: 'Bearer ' + process.env.ROUTERANDROID_KEY } : {};
  const r = await jsonFetch(`${base}/v1/models`, { headers });
  if (!r.ok || !r.body || !Array.isArray(r.body.data)) {
    throw new Error(`/v1/models returned HTTP ${r.status} (set ROUTERANDROID_KEY=sk-... if the endpoint needs a key)`);
  }
  const f = (filter || '').toLowerCase();
  return r.body.data.map((m) => m.id).filter((id) => !f || id.toLowerCase().includes(f)).sort();
}

async function main() {
  const [cmd, ...a] = process.argv.slice(2);
  switch (cmd) {
    case 'resolve': {
      const r = await resolveRelease(a[0]);
      console.log(`${r.version}\n${r.tarball}\n${r.integrity}`);
      break;
    }
    case 'download': {
      if (a.length < 2) throw new Error('usage: download <url> <dest> [integrity]');
      const n = await download(a[0], a[1], a[2]);
      console.log(`downloaded ${(n / 1048576).toFixed(1)} MB, integrity ${a[2] ? 'ok' : 'not checked'}`);
      break;
    }
    case 'create-key': {
      if (a.length < 3) throw new Error('usage: create-key <baseUrl> <password> <name>');
      console.log(await createKey(a[0].replace(/\/+$/, ''), a[1], a[2]));
      break;
    }
    case 'models': {
      if (!a[0]) throw new Error('usage: models <baseUrl> [filter]');
      const ids = await models(a[0].replace(/\/+$/, ''), a[1]);
      console.log(ids.join('\n'));
      break;
    }
    case 'dns': {
      if (!a[0]) throw new Error('usage: dns <host>');
      const t0 = Date.now();
      const res = await require('dns').promises.lookup(a[0], { all: true });
      console.log(res.map((x) => x.address).join(' ') + `  (${Date.now() - t0} ms)`);
      break;
    }
    default:
      throw new Error('unknown command: ' + (cmd || '(none)'));
  }
}

main().catch((e) => { console.error('error: ' + (e && e.message ? e.message : e)); process.exit(1); });
