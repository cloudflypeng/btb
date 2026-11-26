#!/usr/bin/env bash
# Collect BTB perf metrics (plan item A1).
#
#   scripts/perf.sh mac [seconds]          # launches the Debug Mac app
#   scripts/perf.sh ios <udid> [seconds]   # streams logs from a booted simulator
#
# Output: one line per metric, e.g. "launch.firstFeed 312.4 ms source=cache count=30",
# followed by a summary (count / min / p50 / max) per metric.
set -euo pipefail
MODE=${1:-mac}
PRED='subsystem == "com.cloudflypeng.btb.perf"'
OUT=$(mktemp)

case "$MODE" in
  mac)
    SECS=${2:-20}
    APP=.build/Build/Products/Debug/BTB.app
    pkill -x BTB 2>/dev/null || true
    log stream --style compact --level info --predicate "$PRED" > "$OUT" &
    LOGPID=$!
    sleep 1
    open -n "$APP" ${BTB_OPEN_BVID:+--env BTB_OPEN_BVID=$BTB_OPEN_BVID}
    ;;
  ios)
    UDID=${2:?simulator udid}
    SECS=${3:-20}
    xcrun simctl spawn "$UDID" log stream --style compact --level info --predicate "$PRED" > "$OUT" &
    LOGPID=$!
    sleep 1
    xcrun simctl terminate "$UDID" com.cloudflypeng.btb.mobile 2>/dev/null || true
    xcrun simctl launch "$UDID" com.cloudflypeng.btb.mobile >/dev/null
    ;;
  *) echo "usage: $0 mac|ios ..." >&2; exit 2 ;;
esac

echo "collecting for ${SECS}s… interact with the app now (open a video, scroll)"
sleep "$SECS"
kill "$LOGPID" 2>/dev/null || true

grep -o 'perf: .*' "$OUT" | sed 's/^perf: //' | tee "$OUT.lines"
echo "--- summary"
awk '{ n[$1]++; v[$1, n[$1]] = $2 }
  END {
    for (k in n) {
      c = n[k]; for (i = 1; i <= c; i++) a[i] = v[k, i]
      for (i = 1; i <= c; i++) for (j = i + 1; j <= c; j++) if (a[j] < a[i]) { t = a[i]; a[i] = a[j]; a[j] = t }
      printf "%-20s n=%-3d min=%7.1f p50=%7.1f max=%7.1f ms\n", k, c, a[1], a[int((c + 1) / 2)], a[c]
    }
  }' "$OUT.lines"
