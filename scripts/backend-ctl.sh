#!/usr/bin/env bash
# Backend control (background, survives SSH logout).
#   scripts/backend-ctl.sh A|B start|stop|restart|status|log
source "$(dirname "$0")/lib.sh"
ID="${1:?usage: backend-ctl.sh A|B start|stop|restart|status|log}"; ACTION="${2:-status}"
case "$ID" in A) PORT="$BACKEND_A_PORT"; IP="$MAC3_IP" ;; B) PORT="$BACKEND_B_PORT"; IP="$MAC4_IP" ;; *) echo "A|B"; exit 1 ;; esac
PIDF="/tmp/cn-backend-$ID.pid"; LOG="/tmp/cn-backend-$ID.log"
pid_on_port() { lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -1; }
status() {
  P="$(pid_on_port)"; [ -n "$P" ] && ok "Backend $ID LISTENING on *:$PORT (pid $P)" || bad "Backend $ID NOT listening on $PORT"
  run "curl -s -m 2 -i http://127.0.0.1:$PORT/api/status | grep -iE '^HTTP|^x-backend|backend'"
}
case "$ACTION" in
  start)
    [ -n "$(pid_on_port)" ] && { status; exit 0; }
    [ "$(myip)" = "$IP" ] || warn "this Mac is $(myip); env.sh expects Backend $ID on $IP"
    cd "$ROOT/backend" || exit 1
    BACKEND_ID="$ID" PORT="$PORT" nohup python3 server.py >> "$LOG" 2>&1 </dev/null &
    echo $! > "$PIDF"; for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do [ -n "$(pid_on_port)" ] && break; sleep 0.5; done; echo "[$(date +%T)] started Backend $ID"; status ;;
  stop)
    P="$(pid_on_port)"; [ -n "$P" ] && kill "$P" && echo "[$(date +%T)] stopped Backend $ID (pid $P)" || echo "was not running"; rm -f "$PIDF" ;;
  restart) "$0" "$ID" stop; sleep 1; "$0" "$ID" start ;;
  status)  status ;;
  log)     tail -n 20 -f "$LOG" ;;
  *) echo "action: start|stop|restart|status|log"; exit 1 ;;
esac
