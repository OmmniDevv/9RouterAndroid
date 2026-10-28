#!/system/bin/sh
# ============================================================
# 9RouterAndroid — action.sh
# Action button in the KernelSU/Magisk/APatch manager:
# starts 9router if needed, then opens the dashboard.
# ============================================================
H="${ROUTERANDROID_HOME:-/data/adb/9router}"
CTL="$H/bin/9router"

echo "================================"
echo "   9RouterAndroid — Action"
echo "================================"

[ "$(cat "$H/.install_state" 2>/dev/null)" = "done" ] || { echo "Not installed yet — reflash the module"; exit 1; }

"$CTL" start || exit 1

PORT=$(grep -E '^port=' "$H/settings.ini" 2>/dev/null | tail -n 1 | cut -d= -f2 | tr -d '\r')
[ -n "$PORT" ] || PORT=20128
PW=$(grep -E '^initial_password=' "$H/settings.ini" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '\r')

am start -a android.intent.action.VIEW -d "http://127.0.0.1:$PORT/dashboard" >/dev/null 2>&1

echo ""
echo "Dashboard : http://127.0.0.1:$PORT/dashboard"
echo "API base  : http://127.0.0.1:$PORT/v1"
[ -n "$PW" ] && echo "Password  : $PW   (initial — if you changed it in the dashboard, use that)"
echo ""
echo "CLI : su -c 9router status | log | update | link-hermes"
exit 0
