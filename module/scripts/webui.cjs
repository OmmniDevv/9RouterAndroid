// 9RouterAndroid module WebUI server — no dependencies, loopback only.
// Hybrid access, same page, same backend:
//   - KernelSU manager: module WebUI button opens webroot/index.html, which
//     talks to this server on 127.0.0.1 (CORS allowed, loopback only).
//   - Browser: http://127.0.0.1:<webui_port>/ serves the same page directly.
// Started automatically at flash and on boot (service.sh), and by
// `9router webui`. No manual restart dance: saving a setting that needs
// a restart restarts 9router automatically, and the WebUI server itself
// keeps running on its own port.
// It only runs the module control script with an allow-listed command set
// and reads Hermes config for display. API keys posted to /api/link-hermes
// are passed straight to the control script, never logged or returned.
'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');

const H = process.env.ROUTERANDROID_HOME || '/data/adb/9router';
const CTL = path.join(H, 'bin', '9router');
const LOG = path.join(H, '9router.log');
const CONF = path.join(H, 'settings.ini');
const INDEX = path.join(H, 'webui', 'index.html');

function cfg(key, fallback) {
  try {
    const text = fs.readFileSync(CONF, 'utf8');
    const lines = text.split(/\r?\n/).reverse();
    for (const line of lines) {
      const m = line.match(new RegExp('^' + key + '=(.*)$'));
      if (m) return m[1].trim();
    }
  } catch (_) {}
  return fallback;
}

function runCtl(args, timeoutMs) {
  return new Promise((resolve) => {
    let out = '';
    let done = false;
    const child = spawn('sh', [CTL, ...args], { timeout: timeoutMs || 30000 });
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { out += d; });
    child.on('error', (e) => { if (!done) { done = true; resolve({ ok: false, output: String(e) }); } });
    child.on('close', (code) => { if (!done) { done = true; resolve({ ok: code === 0, output: out.trim() }); } });
    setTimeout(() => { try { child.kill('SIGKILL'); } catch (_) {} }, timeoutMs || 30000);
  });
}

function tailLog(lines) {
  try {
    const text = fs.readFileSync(LOG, 'utf8');
    const all = text.split('\n');
    return all.slice(Math.max(0, all.length - lines - 1)).join('\n');
  } catch (e) { return 'Log not available: ' + e.message; }
}

function settings() {
  const out = {};
  for (const k of ['port', 'host', 'autostart', 'max_old_space', 'doh', 'webui_port', 'webui_autostart', 'hermes_dir']) {
    out[k] = cfg(k, k === 'port' ? '20128' : k === 'host' ? '127.0.0.1' : k === 'autostart' ? 'true' : k === 'max_old_space' ? '768' : k === 'doh' ? 'auto' : k === 'webui_port' ? '20129' : k === 'webui_autostart' ? 'true' : '/data/adb/hermes');
  }
  return out;
}

const ALLOWED_SETTINGS = ['port', 'host', 'autostart', 'max_old_space', 'doh', 'webui_port', 'webui_autostart', 'hermes_dir'];
const RESTART_KEYS = ['port', 'host', 'doh', 'max_old_space'];

function hermesCurrent() {
  const hdir = cfg('hermes_dir', '/data/adb/hermes');
  const yml = path.join(hdir, 'home', '.hermes', 'config.yaml');
  try {
    const text = fs.readFileSync(yml, 'utf8');
    const provider = (text.match(/^provider:\s*(.+)$/m) || [])[1] || '';
    const model = (text.match(/^\s*default:\s*(.+)$/m) || [])[1] || '';
    const base = (text.match(/^\s*base_url:\s*(.+)$/m) || [])[1] || '';
    return { found: true, provider: provider.trim(), model: model.trim(), base_url: base.trim(), config: yml };
  } catch (_) {
    return { found: false, config: yml };
  }
}

function send(res, code, obj) {
  const body = typeof obj === 'string' ? obj : JSON.stringify(obj);
  const headers = {
    'Content-Type': typeof obj === 'string' ? 'text/plain; charset=utf-8' : 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  res.writeHead(code, headers);
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (d) => { body += d; if (body.length > 20000) req.destroy(); });
    req.on('end', () => resolve(body));
  });
}

const server = http.createServer(async (req, res) => {
  const remote = req.socket.remoteAddress || '';
  if (remote !== '127.0.0.1' && remote !== '::1' && remote !== '::ffff:127.0.0.1') {
    return send(res, 403, { ok: false, error: 'loopback only' });
  }
  if (req.method === 'OPTIONS') return send(res, 204, '');
  const url = new URL(req.url, 'http://127.0.0.1');
  try {
    if (req.method === 'GET' && url.pathname === '/') {
      const html = fs.readFileSync(INDEX, 'utf8');
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
      return res.end(html);
    }
    if (req.method === 'GET' && url.pathname === '/api/status') {
      const st = await runCtl(['status'], 15000);
      const port = cfg('port', '20128');
      let health = false;
      try {
        const r = await fetch('http://127.0.0.1:' + port + '/api/health', { signal: AbortSignal.timeout(3000) });
        health = r.ok;
      } catch (_) {}
      return send(res, 200, { ok: true, status: st.output, health, settings: settings(), hermes: hermesCurrent(), dashboard: 'http://127.0.0.1:' + port + '/dashboard', api: 'http://127.0.0.1:' + port + '/v1' });
    }
    if (req.method === 'POST' && ['/api/start', '/api/stop', '/api/restart'].includes(url.pathname)) {
      const r = await runCtl([url.pathname.slice(5)], 90000);
      return send(res, 200, r);
    }
    if (req.method === 'GET' && url.pathname === '/api/log') {
      return send(res, 200, { ok: true, log: tailLog(200) });
    }
    if (req.method === 'GET' && url.pathname === '/api/password') {
      const r = await runCtl(['password'], 10000);
      return send(res, 200, r);
    }
    if (req.method === 'GET' && url.pathname === '/api/doctor') {
      const r = await runCtl(['doctor'], 120000);
      return send(res, 200, r);
    }
    if (req.method === 'GET' && url.pathname === '/api/models') {
      const r = await runCtl(['models'], 30000);
      return send(res, 200, { ok: r.ok, models: r.ok ? r.output.split('\n').filter(Boolean) : [], output: r.output });
    }
    if (req.method === 'GET' && url.pathname === '/api/hermes') {
      return send(res, 200, { ok: true, hermes: hermesCurrent() });
    }
    if (req.method === 'POST' && url.pathname === '/api/link-hermes') {
      const data = JSON.parse(await readBody(req) || '{}');
      const model = String(data.model || '').trim();
      const key = String(data.key || '').trim();
      if (!model || /[\s;|&$`]/.test(model)) return send(res, 400, { ok: false, error: 'model tidak valid' });
      const args = ['link-hermes', '--model', model];
      if (key) args.push('--key', key);
      const r = await runCtl(args, 90000);
      // Never echo the key back.
      return send(res, 200, { ok: r.ok, output: key ? r.output.replace(key, '[key disembunyikan]') : r.output });
    }
    if (req.method === 'POST' && url.pathname === '/api/run') {
      // WebUI ini cuma buat jalanin perintah 9router versi terminal.
      // Jadi allow-list-nya = semua subcommand terminal 9router, kecuali
      // 'webui' sendiri (rekursif) dan 'log -f' (tidak pernah selesai).
      // Karakter shell ditolak, jadi tidak ada injeksi perintah di luar
      // control script. Server ini loopback saja, jadi yang bisa
      // memanggilnya hanyalah pemilik HP ini.
      const data = JSON.parse(await readBody(req) || '{}');
      const raw = String(data.cmd || '').trim();
      if (!raw) return send(res, 400, { ok: false, output: 'perintah kosong' });
      if (/[;|&$`<>\\\n\r]/.test(raw)) return send(res, 400, { ok: false, output: 'karakter shell tidak diizinkan' });
      const parts = raw.split(/\s+/).filter(Boolean);
      const cmd = parts[0];
      const allowed = ['status', 'start', 'stop', 'restart', 'log', 'url', 'password', 'version', 'doctor', 'selftest', 'models', 'config', 'link-hermes', 'update', 'rollback'];
      if (!allowed.includes(cmd)) return send(res, 400, { ok: false, output: 'perintah tidak dikenal: ' + cmd });
      if (cmd === 'log' && parts[1] === '-f') return send(res, 400, { ok: false, output: 'log -f tidak didukung di WebUI (tidak pernah selesai), pakai: log 100' });
      if (parts.some((a) => !/^[A-Za-z0-9_\-./:=@+]+$/.test(a))) return send(res, 400, { ok: false, output: 'argumen mengandung karakter tidak diizinkan' });
      const timeout = cmd === 'update' ? 600000 : cmd === 'selftest' || cmd === 'doctor' ? 180000 : cmd === 'start' || cmd === 'restart' ? 90000 : 60000;
      const r = await runCtl(parts, timeout);
      // Jangan pernah mengembalikan API key yang diketik user.
      let out = r.output;
      const keyIdx = parts.indexOf('--key');
      if (keyIdx >= 0 && parts[keyIdx + 1]) out = out.split(parts[keyIdx + 1]).join('[key disembunyikan]');
      return send(res, 200, { ok: r.ok, output: out });
    }
    if (req.method === 'GET' && url.pathname === '/api/settings') {
      return send(res, 200, { ok: true, settings: settings() });
    }
    if (req.method === 'POST' && url.pathname === '/api/settings') {
      const data = JSON.parse(await readBody(req) || '{}');
      const results = [];
      let needsRestart = false;
      for (const [k, v] of Object.entries(data)) {
        if (!ALLOWED_SETTINGS.includes(k) || v === undefined || v === null || String(v).includes('\n')) continue;
        const r = await runCtl(['config', 'set', k, String(v)], 10000);
        results.push(k + '=' + v + ' -> ' + r.output);
        if (RESTART_KEYS.includes(k)) needsRestart = true;
      }
      let restartOut = '';
      if (needsRestart) {
        const rr = await runCtl(['restart'], 90000);
        restartOut = '\n9router di-restart otomatis:\n' + rr.output;
      }
      return send(res, 200, { ok: true, output: results.join('\n') + restartOut });
    }
    return send(res, 404, { ok: false, error: 'not found' });
  } catch (e) {
    return send(res, 500, { ok: false, error: String(e) });
  }
});

const PORT = parseInt(process.env.WEBUI_PORT || cfg('webui_port', '20129'), 10) || 20129;
server.listen(PORT, '127.0.0.1', () => {
  console.log('9RouterAndroid WebUI on http://127.0.0.1:' + PORT + '/');
});
