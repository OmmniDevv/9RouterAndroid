#!/system/bin/sh
# ============================================================
# 9RouterAndroid — customize.sh
# Runs at flash time (root). Sets up glibc + Node.js, downloads the latest
# 9router release from npm, boots it once as a self-test.
#
# Node.js is reused from HermesAndroid when present (hard link, zero extra
# space, survives Hermes being removed); otherwise it is downloaded.
#
# Advanced overrides (env): ROUTERANDROID_HOME, ROUTERANDROID_NODE_SRC,
#                           ROUTERANDROID_SKIP_ARCH_CHECK
# ============================================================

H="${ROUTERANDROID_HOME:-/data/adb/9router}"
LOG="$H/install.log"
GLIBC_TAR="$MODPATH/glibc.tar.gz"
GLIBC_DIR="$H/glibc/lib"
HERMES_DIR="/data/adb/hermes"
NODE="$H/node/bin/node"
NODE_REAL="$H/node/bin/node.real"
NODE_FALLBACK="v22.22.0"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
die() {
  ui_print ""; ui_print "ERROR: $1"; ui_print "Log: $LOG"
  log "FATAL: $1"
  if type abort >/dev/null 2>&1; then abort "$1"; fi
  exit 1
}

# fetch URL OUT — curl, else busybox wget (verified first, unverified as last resort)
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 "$1" -o "$2"
  elif command -v busybox >/dev/null 2>&1; then
    busybox wget -q -O "$2" "$1" 2>/dev/null && return 0
    ui_print "  (TLS verification unavailable in busybox wget — retrying without)"
    log "WARNING: busybox wget without certificate check for $1"
    busybox wget --no-check-certificate -q -O "$2" "$1"
  else
    return 127
  fi
}

ui_print ""
ui_print "  ___  ____              _            "
ui_print " / _ \\|  _ \\ ___  _   _| |_ ___ _ __ "
ui_print "| (_) | |_) / _ \\| | | | __/ _ \\ '__|"
ui_print " \\__, |  _ < (_) | |_| | ||  __/ |   "
ui_print "   /_/|_| \\_\\___/ \\__,_|\\__\\___|_|   "
ui_print "   AI router for rooted Android (aarch64)"
ui_print "   by OmmniDevv"
ui_print ""

mkdir -p "$H"
log "===== Install start ====="

# ── architecture ───────────────────────────────────────────
ARCH=$(uname -m)
if [ -z "$ROUTERANDROID_SKIP_ARCH_CHECK" ] && [ "$ARCH" != "aarch64" ]; then
  die "Unsupported architecture: $ARCH (need aarch64)"
fi
log "arch: $ARCH"

# ── stop a running instance before touching its files ──────
if [ -x "$H/bin/9router" ]; then
  ui_print "- Stopping running 9router..."
  "$H/bin/9router" stop >> "$LOG" 2>&1
fi

mkdir -p "$GLIBC_DIR" "$H/home" "$H/tmp" "$H/bin" "$H/data" "$H/node/bin" "$H/releases"

# ── glibc bundle (always refreshed) ────────────────────────
[ -f "$GLIBC_TAR" ] || die "Missing glibc.tar.gz in module"
rm -rf "$H/glibc"; mkdir -p "$GLIBC_DIR"
tar -xzf "$GLIBC_TAR" -C "$H/glibc" || die "Failed to extract glibc.tar.gz"
chmod 755 "$GLIBC_DIR"/*.so* 2>/dev/null
log "glibc extracted"
ui_print "- glibc runtime ready"

# ── helper files + node wrapper (needed before the first node run) ──
for f in node-compat.cjs nr-tool.cjs webui.cjs; do
  [ -f "$MODPATH/scripts/$f" ] || die "Missing scripts/$f in module"
  cp "$MODPATH/scripts/$f" "$H/$f" || die "Cannot copy $f"
  chmod 644 "$H/$f"
done
mkdir -p "$H/webui"
[ -f "$MODPATH/webui/index.html" ] && cp "$MODPATH/webui/index.html" "$H/webui/index.html"
[ -f "$MODPATH/webroot/index.html" ] && cp "$MODPATH/webroot/index.html" "$H/webui/index.html" 2>/dev/null || true
rm -f "$NODE"
cp "$MODPATH/scripts/node-wrapper.sh" "$NODE" || die "Cannot install node wrapper"
chmod 755 "$NODE"
rm -f "$H/bin/9router"
cp "$MODPATH/scripts/9router.sh" "$H/bin/9router" || die "Cannot install control script"
chmod 755 "$H/bin/9router"

# ── Node.js ────────────────────────────────────────────────
node_ok() { v=$("$NODE" --version 2>&1) && case "$v" in v[0-9]*) return 0 ;; esac; return 1; }

install_node_from() { # install_node_from /path/to/node-binary
  rm -f "$NODE_REAL"
  ln "$1" "$NODE_REAL" 2>/dev/null || cp "$1" "$NODE_REAL" || return 1
  chmod 755 "$NODE_REAL"
  node_ok && return 0
  rm -f "$NODE_REAL"
  return 1
}

HAVE_NODE=false
if [ -n "$ROUTERANDROID_NODE_SRC" ] && [ -f "$ROUTERANDROID_NODE_SRC" ]; then
  install_node_from "$ROUTERANDROID_NODE_SRC" && HAVE_NODE=true
  [ "$HAVE_NODE" = true ] && ui_print "- Using Node.js from \$ROUTERANDROID_NODE_SRC"
elif [ -f "$NODE_REAL" ] && node_ok; then
  HAVE_NODE=true
  ui_print "- Keeping existing Node.js $v"
elif [ -f "$HERMES_DIR/node/bin/node.real" ]; then
  ui_print "- HermesAndroid detected — reusing its Node.js (hard link)"
  if install_node_from "$HERMES_DIR/node/bin/node.real"; then
    HAVE_NODE=true
    log "node reused from Hermes: $v"
  else
    ui_print "  could not reuse it, will download instead"
    log "Hermes node reuse failed: $v"
  fi
fi

if [ "$HAVE_NODE" != true ]; then
  ui_print "- Detecting latest Node.js 22 LTS..."
  NODE_VERSION=""
  if command -v curl >/dev/null 2>&1; then
    NODE_VERSION=$(curl -fsSL --max-time 15 https://nodejs.org/dist/index.json 2>/dev/null \
      | grep -o '"v22\.[0-9]*\.[0-9]*"' | head -n 1 | tr -d '"')
  fi
  [ -n "$NODE_VERSION" ] || { NODE_VERSION="$NODE_FALLBACK"; ui_print "  fallback: $NODE_VERSION"; }
  ui_print "  using Node.js $NODE_VERSION"

  ARCHIVE="node-$NODE_VERSION-linux-arm64.tar.gz"
  ui_print "- Downloading Node.js (~30 MB)..."
  fetch "https://nodejs.org/dist/$NODE_VERSION/$ARCHIVE" "$H/tmp/$ARCHIVE" || die "Failed to download Node.js"

  # integrity check against the published SHASUMS (best effort)
  if command -v sha256sum >/dev/null 2>&1 && \
     fetch "https://nodejs.org/dist/$NODE_VERSION/SHASUMS256.txt" "$H/tmp/SHASUMS256.txt" 2>/dev/null; then
    WANT=$(grep " $ARCHIVE\$" "$H/tmp/SHASUMS256.txt" | cut -d' ' -f1)
    GOT=$(sha256sum "$H/tmp/$ARCHIVE" | cut -d' ' -f1)
    if [ -n "$WANT" ] && [ "$WANT" != "$GOT" ]; then die "Node.js checksum mismatch"; fi
    log "node sha256 ok ($GOT)"
  fi

  rm -rf "$H/tmp/nodex"; mkdir -p "$H/tmp/nodex"
  tar -xzf "$H/tmp/$ARCHIVE" -C "$H/tmp/nodex" || die "Node.js extraction failed"
  NODE_SRC=$(ls -d "$H/tmp/nodex"/node-v*-linux-arm64 2>/dev/null | head -n 1)/bin/node
  [ -f "$NODE_SRC" ] || die "node binary not found in archive"
  mv "$NODE_SRC" "$H/tmp/node.bin"
  rm -rf "$H/tmp/nodex" "$H/tmp/$ARCHIVE" "$H/tmp/SHASUMS256.txt"
  install_node_from "$H/tmp/node.bin" || die "Node.js smoke test failed: $v"
  rm -f "$H/tmp/node.bin"
  log "node downloaded: $v"
fi
ui_print "- Node.js $("$NODE" --version 2>&1) ready"
"$NODE" -e 'require("node:sqlite")' >/dev/null 2>&1 \
  && log "node:sqlite available" \
  || log "node:sqlite NOT available — 9router will use its bundled sql.js (slower)"

# ── Android CA store → NODE_EXTRA_CA_CERTS (best effort) ───
CADIR=/system/etc/security/cacerts
[ -d "$CADIR" ] || CADIR=/apex/com.android.conscrypt/cacerts
if [ -d "$CADIR" ]; then
  cat "$CADIR"/*.0 > "$H/ca-bundle.pem" 2>/dev/null
  log "CA bundle: $(grep -c 'BEGIN CERTIFICATE' "$H/ca-bundle.pem" 2>/dev/null) certs"
fi

# ── default settings (never overwrite) ─────────────────────
if [ ! -f "$H/settings.ini" ]; then
  PW=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 16)
  [ -n "$PW" ] || PW="nr$(date +%s)$$"
  cat > "$H/settings.ini" <<INIEOF
# 9RouterAndroid — settings (apply with: 9router restart)
# Safer default: loopback only. Use host=0.0.0.0 to reach it from your LAN.
port=20128
host=127.0.0.1
autostart=true
# V8 heap limit in MB
max_old_space=768
# Dashboard password until you change it inside the dashboard
initial_password=$PW
# DNS-over-HTTPS resolver for Node (auto|off)
doh=auto
hermes_dir=$HERMES_DIR
webui_port=20129
webui_autostart=true
INIEOF
fi
chmod 600 "$H/settings.ini"

# ── fetch + install the latest 9router release ─────────────
ui_print "- Downloading 9router from npm (~16 MB)..."
ui_print "  details: $LOG"
"$H/bin/9router" update --no-restart >> "$LOG" 2>&1 || die "9router download/extract failed"
ui_print "- 9router $(cat "$H/current/.version" 2>/dev/null) installed"

# ── boot it once, on a spare port, to prove it works here ──
ui_print "- Self-test (booting a throw-away instance)..."
if "$H/bin/9router" selftest >> "$LOG" 2>&1; then
  ui_print "  self-test passed"
else
  ui_print "  WARNING: self-test failed — see $H/selftest.log"
  ui_print "  (module is installed; after reboot run: su -c '9router doctor')"
  log "WARNING: selftest failed"
fi

rm -rf "$H/tmp"; mkdir -p "$H/tmp"

set_perm "$MODPATH/system/bin/9router" root root 0755
set_perm "$MODPATH/system/bin/9router.service" root root 0755
# KernelSU Action/WebUI buttons: action.sh must be executable and webroot
# must be world-readable (the manager app reads it as a non-root user).
# The zip previously shipped webroot/index.html as 660, which can hide
# the WebUI button even though the file is there.
chmod 755 "$MODPATH/action.sh" 2>/dev/null || true
chmod 755 "$MODPATH/webroot" 2>/dev/null || true
chmod 644 "$MODPATH/webroot/index.html" 2>/dev/null || true
chmod 644 "$MODPATH/webui/index.html" 2>/dev/null || true

# KernelSU exec, langsung tanpa reboot (sebelumnya link baru dibuat service.sh
# saat boot, jadi su -c 9router gagal kalau belum reboot, dan overlay
# system/bin tidak selalu muncul di shell KernelSU — pola yang sama dipakai
# HermesAndroid untuk /data/adb/ksu/bin/hermes).
for d in /data/adb/ksu/bin /data/adb/ap/bin; do
  [ -d "$d" ] && ln -sf "$H/bin/9router" "$d/9router"
  [ -f "$MODPATH/system/bin/9router.service" ] && [ -d "$d" ] && cp "$MODPATH/system/bin/9router.service" "$d/9router.service" && chmod 755 "$d/9router.service"
done

"$H/bin/9router" webui start >> "$LOG" 2>&1 || log "WARNING: WebUI server failed to start at flash (will retry on boot)"
echo "done" > "$H/.install_state"
chmod 600 "$H/.install_state"
log "===== Install complete ====="

ui_print ""
ui_print "  Installation completed!"
ui_print ""
ui_print "  CLI langsung bisa dipakai tanpa reboot (KernelSU):
    su -c '9router status'
    su -c '9router webui'
  Reboot (or: su -c '9router start'), then:"
ui_print "    su -c '9router status'"
ui_print "    su -c '9router password'     # dashboard login"
ui_print "  Dashboard: http://127.0.0.1:20128/dashboard"
ui_print "  API base : http://127.0.0.1:20128/v1"
if [ -d "$HERMES_DIR" ]; then
  ui_print ""
  ui_print "  HermesAndroid detected. To point Hermes at 9router:"
  ui_print "    su -c '9router link-hermes --model <model-or-combo>'"
fi
ui_print ""
