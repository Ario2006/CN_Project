#!/usr/bin/env bash
# Ext C - backend service isolation with macOS pf, WITHOUT touching /etc/pf.conf.
# Rules go into the anchor com.apple/250.CNIsolation (the stock /etc/pf.conf already
# evaluates every anchor under "com.apple/*"), so rollback = flush that one anchor.
#   usage (on Mac 3 or Mac 4): scripts/firewall.sh apply|status|rollback [A|B]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
ANCHOR="com.apple/250.CNIsolation"
TOKEN_FILE="/tmp/cn-pf-token"
ACTION="${1:-status}"
MYIP="$(ipconfig getifaddr "$IFACE")"
ID="${2:-}"
[ -z "$ID" ] && { [ "$MYIP" = "$MAC3_IP" ] && ID=A; [ "$MYIP" = "$MAC4_IP" ] && ID=B; }

case "$ACTION" in
  apply)
    [ -n "$ID" ] || { echo "Cannot tell if this is Backend A or B; pass A or B"; exit 1; }
    "$ROOT/scripts/render-configs.sh" firewall >/dev/null
    RULES="$ROOT/firewall/backend-$ID.pf"
    BK="$ROOT/firewall/backup/$(hostname -s)-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK"
    cp /etc/pf.conf "$BK/pf.conf.original"
    sudo pfctl -s info 2>/dev/null | head -1 > "$BK/pf-status-before.txt"
    sudo pfctl -sr 2>/dev/null > "$BK/pf-main-rules-before.txt"
    sudo pfctl -a "$ANCHOR" -sr 2>/dev/null > "$BK/pf-anchor-before.txt"
    echo "Rollback copy saved in ${BK#$ROOT/}"
    sudo pfctl -nf "$RULES" -a "$ANCHOR" || { echo "rule syntax error"; exit 1; }
    sudo pfctl -a "$ANCHOR" -f "$RULES" 2>&1 | grep -v ALTQ
    OUT="$(sudo pfctl -E 2>&1)"; echo "$OUT" | grep -v ALTQ
    echo "$OUT" | awk '/Token/{print $3}' > "$TOKEN_FILE"
    echo "[$(date '+%T')] Isolation ACTIVE on Backend $ID ($MYIP): only $MAC2_IP ${FIREWALL_EXTRA_ALLOW} may reach port $( [ "$ID" = A ] && echo "$BACKEND_A_PORT" || echo "$BACKEND_B_PORT")"
    "$0" status ;;
  status)
    sudo pfctl -s info 2>/dev/null | head -1
    echo "--- rules in anchor $ANCHOR:"; sudo pfctl -a "$ANCHOR" -sr 2>/dev/null || true
    echo "--- live states touching 3001/3002:"; sudo pfctl -ss 2>/dev/null | grep -E ":(${BACKEND_A_PORT}|${BACKEND_B_PORT})\b" | head -5 ;;
  rollback)
    sudo pfctl -a "$ANCHOR" -F all 2>&1 | grep -v ALTQ
    if [ -s "$TOKEN_FILE" ]; then sudo pfctl -X "$(cat "$TOKEN_FILE")" 2>&1 | grep -v ALTQ; rm -f "$TOKEN_FILE"; fi
    echo "[$(date '+%T')] Isolation REMOVED (anchor flushed, our pf enable reference released). /etc/pf.conf was never modified."
    "$0" status ;;
  *) echo "usage: firewall.sh apply|status|rollback [A|B]"; exit 1 ;;
esac
