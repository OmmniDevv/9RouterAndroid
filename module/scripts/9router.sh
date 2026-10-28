#!/system/bin/sh
# ============================================================
# 9RouterAndroid — control script  (installed as bin/9router)
#
#   9router start|stop|restart|status|log [-f]|url|password
#   9router config [set KEY VALUE]
#   9router update [--check] [--version X] [--force]
#   9router rollback
#   9router link-hermes [--key sk-...] [--model ID]
#   9router models [filter]
#   9router doctor | selftest | version
# ============================================================

H="${ROUTERANDROID_HOME:-/data/adb/9router}"
PATH="/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH"
export PATH

CONF="$H/settings.ini"
LOG="$H/9router.log"
PIDF="$H/9router.pid"
NODE="$H/node/bin/node"
TOOL="$H/nr-tool.cjs"
PATTERN="$H/current/app/custom-serve[r].js"   # [r] keeps pgrep from matching itself

# ── settings ────────────────────────────────────────────────
cfg() { # cfg KEY DEFAULT
  v=$(grep -E "^$1=" "$CONF" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '\r')
  if [ -n "$v" ]; then printf '%s\n' "$v"; else printf '%s\n' "$2"; fi
}

cfg_set() { # cfg_set KEY VALUE
  grep -v -E "^$1=" "$CONF" > "$CONF.tmp" 2>/dev/null
  printf '%s=%s\n' "$1" "$2" >> "$CONF.tmp"
  mv "$CONF.tmp" "$CONF"
  chmod 600 "$CONF"
}

probe_host() { # address usable for local probes
  case "$(cfg host 127.0.0.1)" in 0.0.0.0|::|"") echo 127.0.0.1 ;; *) cfg host 127.0.0.1 ;; esac
}

# ── helpers ─────────────────────────────────────────────────
http_ok() { # http_ok URL
  if command -v curl >/dev/null 2>&1; then
    curl -fs --max-time 3 "$1" >/dev/null 2>&1
  elif command -v busybox >/dev/null 2>&1; then
    busybox wget -q -T 3 -O /dev/null "$1" >/dev/null 2>&1
  else
    nr_node -e 'fetch(process.argv[1],{signal:AbortSignal.timeout(3000)}).then(r=>process.exit(r.ok?0:1),()=>process.exit(1))' "$1"
  fi
}

# Run the bundled node with the compat layer preloaded.
nr_node() (
  export HOME="$H/home" TMPDIR="$H/tmp" DATA_DIR="$H/data"
  export ROUTERANDROID_NODE="$NODE" NODE_NO_WARNINGS=1
  export ROUTERANDROID_DOH="$(cfg doh auto)"
  [ -s "$H/ca-bundle.pem" ] && export NODE_EXTRA_CA_CERTS="$H/ca-bundle.pem"
  export NODE_OPTIONS="--require=$H/node-compat.cjs ${NODE_OPTIONS:-}"
  exec "$NODE" "$@"
)

server_pid() { pgrep -f "$PATTERN" 2>/dev/null | head -n 1; }

installed_version() { cat "$H/current/.version" 2>/dev/null; }

need_install() {
  [ -x "$NODE" ] && [ -f "$H/current/app/custom-server.js" ] && return 0
  echo "9router is not installed correctly — reflash the module."
  return 1
}

# launch_server PORT HOST DATADIR LOGFILE  -> background process, prints nothing
launch_server() {
  _port="$1"; _host="$2"; _data="$3"; _log="$4"
  _mem=$(cfg max_old_space 768)
  _pw=$(cfg initial_password "")
  _setsid=""
  command -v setsid >/dev/null 2>&1 && _setsid="setsid"
  (
    cd "$H/current/app" || exit 1
    export HOME="$H/home" TMPDIR="$H/tmp" DATA_DIR="$_data"
    export PORT="$_port" HOSTNAME="$_host" NODE_ENV=production
    export ROUTERANDROID_NODE="$NODE" NODE_NO_WARNINGS=1
    export ROUTERANDROID_DOH="$(cfg doh auto)"
    [ -n "$_pw" ] && export INITIAL_PASSWORD="$_pw"
    [ -s "$H/ca-bundle.pem" ] && export NODE_EXTRA_CA_CERTS="$H/ca-bundle.pem"
    [ -d "$_data/runtime/node_modules" ] && export NODE_PATH="$_data/runtime/node_modules"
    export NODE_OPTIONS="--require=$H/node-compat.cjs ${NODE_OPTIONS:-}"
    # shellcheck disable=SC2086
    exec $_setsid nohup "$NODE" --dns-result-order=ipv4first \
      --max-old-space-size="$_mem" "$H/current/app/custom-server.js" \
      >> "$_log" 2>&1 < /dev/null
  ) &
}

wait_health() { # wait_health PORT SECONDS PID
  _i=0
  while [ "$_i" -lt "$2" ]; do
    kill -0 "$3" 2>/dev/null || return 2          # died
    http_ok "http://127.0.0.1:$1/api/health" && return 0
    sleep 1
    _i=$((_i + 1))
  done
  return 1
}

# ── commands ────────────────────────────────────────────────
do_start() { # do_start [--nowait]
  need_install || return 1
  pid=$(server_pid)
  if [ -n "$pid" ]; then echo "9router already running (PID $pid)"; return 0; fi

  mkdir -p "$H/home" "$H/tmp" "$H/data"
  # rotate log at 2 MB
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 2097152 ]; then
    mv -f "$LOG" "$LOG.1"
  fi

  port=$(cfg port 20128)
  host=$(cfg host 127.0.0.1)
  echo "[$(date '+%F %T')] starting 9router $(installed_version) on $host:$port" >> "$LOG"
  launch_server "$port" "$host" "$H/data" "$LOG"
  bgpid=$!
  sleep 1
  pid=$(server_pid); [ -n "$pid" ] || pid="$bgpid"
  echo "$pid" > "$PIDF"

  if [ "${1:-}" = "--nowait" ]; then echo "9router starting (PID $pid)"; return 0; fi
  echo "Starting 9router (PID $pid)..."
  wait_health "$port" 60 "$pid"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "9router is up:  http://127.0.0.1:$port/dashboard"
    return 0
  fi
  [ "$rc" -eq 2 ] && echo "9router exited right after start." || echo "9router did not become healthy in 60 s."
  echo "--- last log lines ($LOG) ---"
  tail -n 15 "$LOG" 2>/dev/null
  return 1
}

do_stop() {
  pid=$(server_pid)
  if [ -z "$pid" ]; then echo "9router not running"; rm -f "$PIDF"; return 0; fi
  pkill -f "$PATTERN" 2>/dev/null
  i=0
  while [ "$i" -lt 20 ] && [ -n "$(server_pid)" ]; do sleep 0.5; i=$((i + 1)); done
  if [ -n "$(server_pid)" ]; then pkill -9 -f "$PATTERN" 2>/dev/null; sleep 1; fi
  rm -f "$PIDF"
  echo "9router stopped"
}

do_status() {
  pid=$(server_pid)
  port=$(cfg port 20128)
  echo "module : 9RouterAndroid"
  prev=$(cat "$H/previous-release" 2>/dev/null)
  [ -n "$prev" ] && prev=$(basename "$prev")
  echo "9router: $(installed_version)  (previous: ${prev:-none})"
  if [ -n "$pid" ]; then
    echo "state  : running (PID $pid)"
    if http_ok "http://$(probe_host):$port/api/health"; then echo "health : ok"; else echo "health : NOT responding"; fi
  else
    echo "state  : stopped"
  fi
  echo "bind   : $(cfg host 127.0.0.1):$port   (autostart=$(cfg autostart true))"
  echo "web UI : http://127.0.0.1:$port/dashboard"
  echo "API    : http://127.0.0.1:$port/v1"
  echo "node   : $("$NODE" --version 2>&1 | head -n 1)"
}

do_log() {
  if [ "${1:-}" = "-f" ]; then tail -f "$LOG"; else tail -n "${1:-60}" "$LOG"; fi
}

do_password() {
  pw=$(cfg initial_password "")
  echo "Dashboard password (initial): ${pw:-<none set, upstream default 123456>}"
  echo "If you changed it inside the dashboard, that new password is what counts."
}

do_config() {
  if [ "${1:-}" = "set" ]; then
    k="$2"; v="$3"
    case "$k" in
      port|host|autostart|max_old_space|doh|initial_password|hermes_dir) ;;
      *) echo "unknown key '$k' (port host autostart max_old_space doh initial_password hermes_dir)"; return 2 ;;
    esac
    [ -n "$v" ] || { echo "usage: 9router config set KEY VALUE"; return 2; }
    cfg_set "$k" "$v"
    echo "$k=$v   (run '9router restart' to apply)"
  else
    sed -e 's/^\(initial_password=\).*/\1********/' "$CONF"
  fi
}

do_models() {
  need_install || return 1
  nr_node "$TOOL" models "http://127.0.0.1:$(cfg port 20128)" "$1"
}

# ── update / rollback ───────────────────────────────────────
do_update() {
  check=0; force=0; norestart=0; want=latest
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check=1 ;;
      --force) force=1 ;;
      --no-restart) norestart=1 ;;
      --version) shift; want="$1" ;;
      *) echo "usage: 9router update [--check] [--version X] [--force]"; return 2 ;;
    esac
    shift
  done
  [ -x "$NODE" ] || { echo "node runtime missing — reflash the module"; return 1; }

  if ! mkdir "$H/update.lock" 2>/dev/null; then
    echo "another update is running (remove $H/update.lock if it is stale)"; return 1
  fi
  trap 'rmdir "$H/update.lock" 2>/dev/null' EXIT

  out=$(nr_node "$TOOL" resolve "$want") || { echo "could not resolve the release from the npm registry"; return 1; }
  ver=$(printf '%s\n' "$out" | sed -n 1p)
  url=$(printf '%s\n' "$out" | sed -n 2p)
  sri=$(printf '%s\n' "$out" | sed -n 3p)
  cur=$(installed_version)
  echo "installed: ${cur:-none}   target: $ver"

  if [ "$check" -eq 1 ]; then
    if [ "$cur" = "$ver" ]; then echo "up to date"; else echo "update available"; fi
    return 0
  fi
  if [ "$cur" = "$ver" ] && [ "$force" -eq 0 ]; then echo "already at $ver"; return 0; fi

  rel="$H/releases/$ver"
  if [ ! -f "$rel/app/custom-server.js" ]; then
    mkdir -p "$H/tmp" "$H/releases"
    tgz="$H/tmp/9router-$ver.tgz"
    echo "Downloading 9router $ver ..."
    nr_node "$TOOL" download "$url" "$tgz" "$sri" || { rm -f "$tgz"; echo "download failed"; return 1; }
    rm -rf "$rel.new"; mkdir -p "$rel.new"
    echo "Extracting ..."
    tar -xzf "$tgz" -C "$rel.new" --strip-components=1 || { rm -rf "$rel.new" "$tgz"; echo "extract failed"; return 1; }
    rm -f "$tgz"
    [ -f "$rel.new/app/custom-server.js" ] || { rm -rf "$rel.new"; echo "release looks wrong (no app/custom-server.js)"; return 1; }
    printf '%s\n' "$ver" > "$rel.new/.version"
    rm -rf "$rel"; mv "$rel.new" "$rel"
  fi

  was_running=$(server_pid)
  [ -n "$was_running" ] && do_stop
  old=$(readlink "$H/current" 2>/dev/null)
  rm -f "$H/current"; ln -s "$rel" "$H/current"
  [ -n "$old" ] && [ "$old" != "$rel" ] && printf '%s\n' "$old" > "$H/previous-release"

  if [ "$norestart" -eq 0 ] && [ -n "$was_running" ]; then
    if ! do_start; then
      echo "New release failed to start — restoring ${old:-previous}."
      do_stop
      if [ -n "$old" ] && [ -f "$old/app/custom-server.js" ]; then
        rm -f "$H/current"; ln -s "$old" "$H/current"
        do_start
      fi
      return 1
    fi
  fi

  # keep only current + previous
  for d in "$H/releases"/*; do
    [ -d "$d" ] || continue
    [ "$d" = "$rel" ] && continue
    [ "$d" = "$old" ] && continue
    rm -rf "$d"
  done
  echo "9router is now $ver"
  return 0
}

do_rollback() {
  prev=$(cat "$H/previous-release" 2>/dev/null)
  if [ -z "$prev" ] || [ ! -f "$prev/app/custom-server.js" ]; then echo "no previous release to roll back to"; return 1; fi
  curr=$(readlink "$H/current" 2>/dev/null)
  was_running=$(server_pid)
  [ -n "$was_running" ] && do_stop
  rm -f "$H/current"; ln -s "$prev" "$H/current"
  [ -n "$curr" ] && printf '%s\n' "$curr" > "$H/previous-release"
  echo "rolled back to $(installed_version)"
  [ -n "$was_running" ] && do_start
  return 0
}

# ── Hermes integration ──────────────────────────────────────
do_link_hermes() {
  key=""; model=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --key) shift; key="$1" ;;
      --model) shift; model="$1" ;;
      *) echo "usage: 9router link-hermes [--key sk-...] [--model provider/model]"; return 2 ;;
    esac
    shift
  done
  need_install || return 1
  hdir=$(cfg hermes_dir /data/adb/hermes)
  hhome="$hdir/home/.hermes"
  [ -d "$hdir" ] || { echo "HermesAndroid not found at $hdir (set: 9router config set hermes_dir PATH)"; return 1; }

  port=$(cfg port 20128)
  base="http://127.0.0.1:$port/v1"

  if [ -z "$key" ]; then
    if [ -z "$(server_pid)" ]; then echo "9router is not running — starting it first"; do_start || return 1; fi
    echo "Creating/reusing API key 'hermes-android' via the dashboard API ..."
    key=$(nr_node "$TOOL" create-key "http://127.0.0.1:$port" "$(cfg initial_password 123456)" hermes-android) || return 1
  fi

  mkdir -p "$hhome"
  envf="$hhome/.env"
  [ -f "$envf" ] && [ ! -f "$envf.routerandroid.bak" ] && cp "$envf" "$envf.routerandroid.bak"
  touch "$envf"; chmod 600 "$envf"
  grep -v -E '^(OPENAI_API_KEY|OPENAI_BASE_URL)=' "$envf" > "$envf.tmp" 2>/dev/null
  printf 'OPENAI_API_KEY=%s\nOPENAI_BASE_URL=%s\n' "$key" "$base" >> "$envf.tmp"
  mv "$envf.tmp" "$envf"; chmod 600 "$envf"
  echo "Hermes .env updated  ($envf)"
  echo "  OPENAI_BASE_URL=$base"

  yml="$hhome/config.yaml"
  patched=0
  if [ -n "$model" ]; then
    for py in "$hdir/current/bin/python" "$hdir/bin/python"; do
      [ -x "$py" ] || continue
      "$py" -c 'import yaml' >/dev/null 2>&1 || continue
      [ -f "$yml" ] && [ ! -f "$yml.routerandroid.bak" ] && cp "$yml" "$yml.routerandroid.bak"
      if HOME="$hdir/home" TMPDIR="$hdir/tmp" "$py" - "$yml" "$model" "$base" <<'PYEOF'
import sys, yaml
path, model, base = sys.argv[1:4]
try:
    with open(path) as f:
        data = yaml.safe_load(f) or {}
except FileNotFoundError:
    data = {}
cur = data.get("model")
if isinstance(cur, str) and cur:
    cur = {"default": cur}
if not isinstance(cur, dict):
    cur = {}
cur.update({"provider": "custom", "base_url": base, "default": model})
data["model"] = cur
with open(path, "w") as f:
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
PYEOF
      then patched=1; break; fi
    done
  fi

  if [ "$patched" -eq 1 ]; then
    echo "Hermes config.yaml updated  ($yml)  model=$model"
  else
    echo ""
    echo "Finish in Hermes' config.yaml ($yml):"
    echo "  model:"
    echo "    provider: custom"
    echo "    default: ${model:-<pick a model/combo from the 9router dashboard>}"
    echo "    base_url: $base"
    echo "(or run 'hermes setup' → Custom OpenAI-compatible endpoint, with the URL and key above)"
    [ -z "$model" ] && echo "Tip: '9router models' lists model ids; then re-run: 9router link-hermes --model <id>"
  fi
  echo ""
  echo "Restart Hermes to apply:  hermes.service restart"
  return 0
}

# ── diagnostics ─────────────────────────────────────────────
do_selftest() { # boots a throw-away instance on a spare port with an empty data dir
  need_install || return 1
  if [ -n "$(server_pid)" ]; then echo "selftest needs 9router stopped first:  9router stop"; return 1; fi
  port="${1:-20190}"
  d="$H/tmp/selftest"
  rm -rf "$d"; mkdir -p "$d" "$H/home" "$H/tmp"
  launch_server "$port" 127.0.0.1 "$d/data" "$d/server.log"
  pid=$!
  wait_health "$port" 60 "$pid"
  rc=$?
  kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null
  pkill -f "$PATTERN" 2>/dev/null
  if [ "$rc" -ne 0 ]; then
    echo "selftest FAILED (rc=$rc). Last log lines:"
    tail -n 20 "$d/server.log" 2>/dev/null
    cp "$d/server.log" "$H/selftest.log" 2>/dev/null
    rm -rf "$d"
    return 1
  fi
  rm -rf "$d"
  echo "selftest ok"
  return 0
}

do_doctor() {
  echo "== runtime"
  "$NODE" -e 'const v=process.versions;let s;try{require("node:sqlite");s="yes"}catch(e){s="no"}console.log("node",v.node,process.arch,"| node:sqlite:",s,"| glibc:",process.report.getReport().header.glibcVersionRuntime)' 2>&1
  echo "== disk"; df -h "$H" 2>/dev/null | tail -n 1
  echo "== dns / https"
  nr_node "$TOOL" dns registry.npmjs.org 2>&1
  echo "== server"; do_status
  echo "== settings"; do_config
}

usage() {
  cat <<EOF
9RouterAndroid
  9router start | stop | restart | status
  9router log [-f|N]        show / follow the log
  9router url               dashboard + API endpoints
  9router password          show the initial dashboard password
  9router config [set K V]  keys: port host autostart max_old_space doh initial_password hermes_dir
  9router update [--check] [--version X] [--force]
  9router rollback
  9router link-hermes [--key sk-...] [--model ID]
  9router models [filter]
  9router doctor | selftest | version
EOF
}

case "${1:-status}" in
  start)         shift; do_start "$@" ;;
  stop)          do_stop ;;
  restart)       do_stop; sleep 1; do_start ;;
  status)        do_status ;;
  log)           shift; do_log "$@" ;;
  url)           p=$(cfg port 20128); echo "Dashboard: http://127.0.0.1:$p/dashboard"; echo "API base : http://127.0.0.1:$p/v1" ;;
  password)      do_password ;;
  config)        shift; do_config "$@" ;;
  update)        shift; do_update "$@" ;;
  rollback)      do_rollback ;;
  link-hermes)   shift; do_link_hermes "$@" ;;
  models)        shift; do_models "$@" ;;
  selftest)      shift; do_selftest "$@" ;;
  doctor)        do_doctor ;;
  version)       echo "9router $(installed_version)  (module $(grep '^version=' "$H/../modules/scripts/module.prop" 2>/dev/null | cut -d= -f2))" ;;
  -h|--help|help) usage ;;
  *)             usage; exit 2 ;;
esac
