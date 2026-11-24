#!/usr/bin/env bash
# Start/stop the team dnsmasq in the background (safe to run over SSH).
#   usage: scripts/dns-ctl.sh primary|backup start|stop|restart|status|log
#   primary = Mac 1 (dns/team-dnsmasq.conf)   backup = BACKUP_DNS_IP Mac (dns/team-dnsmasq-backup.conf)
# Log: /tmp/dnsmasq-cn-<role>.log  (every query + which record answered = live evidence)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
ROLE="${1:?usage: dns-ctl.sh primary|backup start|stop|restart|status|log}"; ACTION="${2:-status}"
case "$ROLE" in
  primary) CONF="$ROOT/dns/team-dnsmasq.conf";        WANT_IP="$MAC1_IP" ;;
  backup)  CONF="$ROOT/dns/team-dnsmasq-backup.conf"; WANT_IP="$BACKUP_DNS_IP" ;;
  *) echo "role must be primary or backup"; exit 1 ;;
esac
LOG="/tmp/dnsmasq-cn-$ROLE.log"
PAT="dnsmasq.*$(basename "$CONF")"
DNSMASQ="$(command -v dnsmasq || echo /opt/homebrew/sbin/dnsmasq)"
MYIP="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"

status() {
  if pgrep -f "$PAT" >/dev/null; then echo "dnsmasq ($ROLE) RUNNING  pid(s): $(pgrep -f "$PAT" | tr '\n' ' ')"
  else echo "dnsmasq ($ROLE) STOPPED"; fi
  dig +time=1 +tries=1 @"$WANT_IP" "app.$DOMAIN" +noall +answer 2>/dev/null | grep -v '^;' || echo "  (no answer from $WANT_IP:53)"
}
start() {
  [ -x "$DNSMASQ" ] || { echo "dnsmasq not installed: brew install dnsmasq"; exit 1; }
  [ "$MYIP" = "$WANT_IP" ] || echo "WARNING: this Mac is $MYIP but $ROLE DNS must listen on $WANT_IP (env.sh out of date?)"
  pgrep -f "$PAT" >/dev/null && { echo "already running"; status; return; }
  "$DNSMASQ" --test -C "$CONF" || exit 1
  sudo sh -c "nohup '$DNSMASQ' -k -C '$CONF' >> '$LOG' 2>&1 &"
  sleep 1; echo "started $ROLE DNS at $(date '+%T')  (log: $LOG)"; status
}
stop() {
  sudo pkill -f "$PAT" && echo "stopped $ROLE DNS at $(date '+%T')" || echo "was not running"
}
case "$ACTION" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  log) tail -n 30 -f "$LOG" ;;
  *) echo "action: start|stop|restart|status|log"; exit 1 ;;
esac
