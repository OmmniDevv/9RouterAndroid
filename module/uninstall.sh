#!/system/bin/sh
# ============================================================
# 9RouterAndroid — uninstall.sh
# Runs when the module is removed. Preserves $H/data (database,
# provider credentials, API keys) and $H/settings.ini so a reinstall
# picks up where you left off.
# ============================================================
H="${ROUTERANDROID_HOME:-/data/adb/9router}"

[ -x "$H/bin/9router" ] && "$H/bin/9router" stop >/dev/null 2>&1
pkill -f "$H/current/app/custom-serve[r].js" 2>/dev/null

rm -f /data/adb/ksu/bin/9router /data/adb/ap/bin/9router

# Runtime (re-downloadable). node.real may be a hard link shared with
# HermesAndroid — removing our link leaves Hermes' copy untouched.
rm -rf "$H/glibc" "$H/node" "$H/releases" "$H/bin"
rm -f  "$H/current" "$H/previous-release" "$H/node-compat.cjs" "$H/nr-tool.cjs"
rm -rf "$H/tmp" "$H/home" "$H/update.lock"
rm -f  "$H/ca-bundle.pem" "$H/.install_state" "$H/9router.pid"
rm -f  "$H/install.log" "$H/9router.log" "$H/9router.log.1" "$H/selftest.log"

echo "9RouterAndroid uninstalled. Data and settings preserved at $H/data and $H/settings.ini"
