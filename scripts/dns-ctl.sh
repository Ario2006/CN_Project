#!/usr/bin/env bash
# dnsmasq control (background, survives SSH logout).
#   scripts/dns-ctl.sh primary|backup start|stop|restart|status|log
#   primary = Mac 1, dns/team-dnsmasq.conf      backup = Mac 3, dns/team-dnsmasq-backup.conf
source "$(dirname "$0")/lib.sh"
ROLE="${1:?usage: dns-ctl.sh primary|backup start|stop|restart|status|log}"; ACTION="${2:-status}"
case "$ROLE" in
  primary) CONF="$ROOT/dns/team-dnsmasq.conf";        IP="$MAC1_IP" ;;
  backup)  CONF="$ROOT/dns/team-dnsmasq-backup.conf"; IP="$BACKUP_DNS_IP" ;;
  *) echo "role: primary|backup"; exit 1 ;;
esac
LOG="/tmp/dnsmasq-cn-$ROLE.log"; PAT="dnsmasq -k -C $CONF"
status() {
  if pgrep -f "$PAT" >/dev/null; then ok "dnsmasq $ROLE RUNNING (pid $(pgrep -f "$PAT" | head -1)) on $IP:53"; else bad "dnsmasq $ROLE STOPPED"; fi
  run "dig +time=1 +tries=1 @$IP $APP +noall +answer"
}
case "$ACTION" in
  start)
    [ "$(myip)" = "$IP" ] || warn "this Mac is $(myip) but $ROLE DNS must be $IP"
    pgrep -f "$PAT" >/dev/null && { status; exit 0; }
    "$DNSMASQ" --test -C "$CONF" || exit 1
    sudo -n "$DNSMASQ" --version >/dev/null 2>&1 || sudo "$DNSMASQ" --version >/dev/null   # get sudo ready in foreground
    nohup sudo "$DNSMASQ" -k -C "$CONF" >> "$LOG" 2>&1 </dev/null &
    sleep 1; echo "[$(date +%T)] started $ROLE DNS  (log: $LOG)"; status ;;
  stop)    run "sudo pkill -f '$PAT'" && echo "[$(date +%T)] stopped $ROLE DNS" || echo "was not running" ;;
  restart) "$0" "$ROLE" stop; sleep 1; "$0" "$ROLE" start ;;
  status)  status ;;
  log)     tail -n 20 -f "$LOG" ;;
  *) echo "action: start|stop|restart|status|log"; exit 1 ;;
esac
