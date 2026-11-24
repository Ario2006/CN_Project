#!/usr/bin/env bash
# Start/stop a backend in the background (safe over SSH).
#   usage: scripts/backend-ctl.sh A|B start|stop|restart|status|log
# Log: /tmp/cn-backend-<A|B>.log (shows the nginx IP:port of every request)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
ID="${1:?usage: backend-ctl.sh A|B start|stop|restart|status|log}"; ACTION="${2:-status}"
case "$ID" in A) PORT="$BACKEND_A_PORT"; WANT_IP="$MAC3_IP" ;; B) PORT="$BACKEND_B_PORT"; WANT_IP="$MAC4_IP" ;; *) echo "A or B"; exit 1 ;; esac
PIDF="/tmp/cn-backend-$ID.pid"; LOG="/tmp/cn-backend-$ID.log"
running() { [ -s "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }
status() {
  running && echo "Backend $ID RUNNING pid $(cat "$PIDF")" || echo "Backend $ID STOPPED (by this script; check lsof below for a manual one)"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | tail -n +2
}
case "$ACTION" in
  start)
    running && { echo "already running"; status; exit 0; }
    MYIP="$(ipconfig getifaddr "$IFACE")"; [ "$MYIP" = "$WANT_IP" ] || echo "WARNING: this Mac is $MYIP, env.sh expects Backend $ID on $WANT_IP"
    cd "$ROOT/backend" || exit 1
    BACKEND_ID="$ID" PORT="$PORT" nohup python3 server.py >> "$LOG" 2>&1 &
    echo $! > "$PIDF"; sleep 1; echo "started Backend $ID at $(date '+%T')"; status ;;
  stop)
    if running; then kill "$(cat "$PIDF")"; rm -f "$PIDF"; echo "stopped Backend $ID at $(date '+%T')"
    else pkill -f "server.py" && echo "stopped (pkill server.py)" || echo "was not running"; fi ;;
  restart) "$0" "$ID" stop; sleep 1; "$0" "$ID" start ;;
  status) status ;;
  log) tail -n 30 -f "$LOG" ;;
  *) echo "action: start|stop|restart|status|log"; exit 1 ;;
esac
