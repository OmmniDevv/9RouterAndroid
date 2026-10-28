#!/system/bin/sh
# ============================================================
# 9RouterAndroid — service.sh
# Runs on every boot (root). Exposes the CLI, then starts 9router
# unless autostart=false.
# ============================================================
H="${ROUTERANDROID_HOME:-/data/adb/9router}"
LOG="$H/9router.log"

[ "$(cat "$H/.install_state" 2>/dev/null)" = "done" ] || exit 0
[ -x "$H/bin/9router" ] || { echo "[$(date '+%T')] control script missing" >> "$LOG"; exit 1; }

# Expose the CLI on root PATH. KernelSU/APatch don't reliably materialise
# module system/ overlays, so link into their own bin dirs (Magisk uses
# the system/bin/9router overlay shipped in the module).
for d in /data/adb/ksu/bin /data/adb/ap/bin; do
  [ -d "$d" ] && ln -sf "$H/bin/9router" "$d/9router"
done

# Service controller, same pattern as HermesAndroid: copy (not symlink, so it
# survives module updates) to the bin dirs that ship in every KSU/APatch root shell.
SVC_SRC="/data/adb/modules/routerandroid/system/bin/9router.service"
[ -f "$SVC_SRC" ] || SVC_SRC="${MODDIR:-/data/adb/modules/routerandroid}/system/bin/9router.service"
for d in /data/adb/ksu/bin /data/adb/ap/bin; do
  [ -f "$SVC_SRC" ] && [ -d "$d" ] && cp "$SVC_SRC" "$d/9router.service" && chmod 755 "$d/9router.service"
done

# Wait for the system to finish booting (max ~3 min)
n=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$n" -lt 90 ]; do
  sleep 2; n=$((n + 1))
done

AUTOSTART=$(grep -E '^autostart=' "$H/settings.ini" 2>/dev/null | tail -n 1 | cut -d= -f2 | tr -d '\r')
if [ "$AUTOSTART" = "false" ]; then
  echo "[$(date '+%T')] autostart=false — not starting" >> "$LOG"
  exit 0
fi

if [ "$(grep -E '^webui_autostart=' "$H/settings.ini" 2>/dev/null | tail -n 1 | cut -d= -f2 | tr -d '\r')" != "false" ]; then
  "$H/bin/9router" webui start >> "$LOG" 2>&1 || true
fi

"$H/bin/9router" start --nowait >> "$LOG" 2>&1
exit 0
