#!/usr/bin/env bash
# Ext B / Ext E: point app.$DOMAIN at a new IP and restart THIS Mac's dnsmasq.
#   usage: scripts/dns-set-app.sh <ip | primary | standby | mac1..mac4>
# Run it on the primary DNS Mac AND on the backup DNS Mac (both must serve the same answer).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
T="${1:?usage: dns-set-app.sh <ip|primary|standby|mac1..mac4>}"
case "$T" in
  primary|mac2) IP="$MAC2_IP" ;; standby) IP="$STANDBY_EDGE_IP" ;;
  mac1) IP="$MAC1_IP" ;; mac3) IP="$MAC3_IP" ;; mac4) IP="$MAC4_IP" ;; *) IP="$T" ;;
esac
MYIP="$(ipconfig getifaddr "$IFACE")"
if   [ "$MYIP" = "$MAC1_IP" ];       then ROLE=primary; CONF="$ROOT/dns/team-dnsmasq.conf"
elif [ "$MYIP" = "$BACKUP_DNS_IP" ]; then ROLE=backup;  CONF="$ROOT/dns/team-dnsmasq-backup.conf"
else echo "This Mac ($MYIP) is neither primary ($MAC1_IP) nor backup ($BACKUP_DNS_IP) DNS"; exit 1; fi

OLD="$(dig +short +time=1 +tries=1 @"$MYIP" "app.$DOMAIN" | head -1 || true)"
APP_RECORD_IP="$IP" "$ROOT/scripts/render-configs.sh" dns >/dev/null
grep "^host-record=app" "$CONF"
"$ROOT/scripts/dns-ctl.sh" "$ROLE" restart >/dev/null
NEW="$(dig +short +time=1 +tries=1 @"$MYIP" "app.$DOMAIN" | head -1 || true)"
echo "[$(date '+%T')] $ROLE DNS: app.$DOMAIN  ${OLD:-?}  ->  ${NEW:-?}   (TTL ${DNS_TTL}s)"
echo "Clients that cached ${OLD:-the old answer} keep using it for up to ${DNS_TTL}s."
[ "$ROLE" = primary ] && echo "REMEMBER: run the same command on the backup DNS ($BACKUP_DNS_LABEL) if clients list it."
exit 0
