#!/system/bin/sh
# 9Router node wrapper — runs Node.js through the bundled glibc loader.
H="${ROUTERANDROID_HOME:-/data/adb/9router}"
unset LD_PRELOAD
export HOME="${HOME:-$H/home}"
export TMPDIR="${TMPDIR:-$H/tmp}"

# Escape hatch for running on a normal glibc Linux box (testing only).
if [ "${ROUTERANDROID_NATIVE_NODE:-0}" = "1" ]; then
  exec "$H/node/bin/node.real" "$@"
fi

LDR="$H/glibc/lib/ld-linux-aarch64.so.1"
if [ ! -x "$LDR" ]; then
  echo "9router: glibc loader missing: $LDR (reflash the module)" >&2
  exit 127
fi
exec "$LDR" --library-path "$H/glibc/lib" "$H/node/bin/node.real" "$@"
