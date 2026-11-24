#!/usr/bin/env bash
# Ext F - systematic, bottom-up fault isolation from a CLIENT Mac.
#   usage: scripts/diagnose.sh [name] [path]        default: app.$DOMAIN /api/status
# Order (as the project doc demands): LAN -> DNS -> IP -> TCP -> TLS -> HTTP -> backend.
# Stops at the FIRST failing layer and says which layer + what to check next.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
NAME="${1:-app.$DOMAIN}"; P="${2:-/api/status}"; PORT="$HTTPS_PORT"
ok(){ printf '  \033[32mOK\033[0m   %s\n' "$*"; }
bad(){ printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
info(){ printf '       %s\n' "$*"; }
WRONG=""
verdict(){
  printf '\n\033[1;31m==> FAULT LAYER: %s\033[0m\n    %s\n' "$1" "$2"
  [ -n "$WRONG" ] && printf '\033[1;31m==> ROOT CAUSE: DNS DATA - %s resolves to %s, which is not an edge. Resolution WORKS but the directory entry is wrong.\033[0m\n    Fix the record on BOTH DNS servers (scripts/dns-set-app.sh primary) and flush client caches.\n' "$NAME" "$WRONG"
  exit 1; }
hdr(){ printf '\n\033[1m[%s] %s\033[0m\n' "$1" "$2"; }

hdr 1 "LAN / L3 - am I on the network?"
MYIP="$(ipconfig getifaddr "$IFACE")"; GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
[ -n "$MYIP" ] && ok "this Mac $MYIP on $IFACE, gateway ${GW:-none}" || verdict "L1/L2 (no IP on $IFACE)" "Wi-Fi connected? same SSID as the team?"
ping -c1 -t2 "$MAC1_IP" >/dev/null 2>&1 && ok "ping DNS Mac1 $MAC1_IP" || bad "ping DNS Mac1 $MAC1_IP (ICMP may also be filtered)"

hdr 2 "DNS - does the name resolve, via whom, to what?"
info "resolvers: $(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ')"
case " $(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ') " in
  *" $MAC1_IP "*|*" $BACKUP_DNS_IP "*) ok "team DNS server is configured";;
  *) bad "client is NOT using team DNS ($MAC1_IP / $BACKUP_DNS_IP)";;
esac
grep -i "$DOMAIN" /etc/hosts >/dev/null 2>&1 && bad "/etc/hosts has an entry for $DOMAIN -> overrides DNS!: $(grep -i "$DOMAIN" /etc/hosts)"
for s in "$MAC1_IP" "$BACKUP_DNS_IP"; do
  r="$(dig +time=2 +tries=1 @"$s" "$NAME" A +short 2>&1 | head -1)"; info "dig @$s -> ${r:-no answer}"
done
IP="$(dscacheutil -q host -a name "$NAME" | awk '/ip_address/{print $2; exit}')"
[ -n "$IP" ] || verdict "DNS (name resolution)" "Name does not resolve. dnsmasq running on Mac1/backup? client resolver list? record exists? (dig @server shows above)"
ok "system resolver: $NAME -> $IP"
case "$IP" in
  "$MAC2_IP") ok "points to primary edge Mac 2";;
  "$STANDBY_EDGE_IP") info "points to STANDBY edge ($STANDBY_EDGE_LABEL) - expected only after an Ext E cutover";;
  *) bad "points to $IP which is NOT an edge (expected $MAC2_IP) -> wrong DNS record? (DNS works, but it's a directory with a wrong entry)"; WRONG="$IP";;
esac

hdr 3 "IP reachability to $IP"
ping -c2 -t3 "$IP" >/dev/null 2>&1 && ok "ping $IP" || { bad "no ICMP reply from $IP"; info "host down / wrong IP / ICMP filtered - TCP test decides"; }
ARP="$(arp -n "$IP" 2>/dev/null | awk '{print $4}')"; info "ARP: $IP is-at ${ARP:-?}"

hdr 4 "TCP - is anything listening on $IP:$PORT?"
NC="$(nc -vz -G 3 "$IP" "$PORT" 2>&1 | tail -1)"; info "$NC"
case "$NC" in
  *succeeded*) ok "TCP 3-way handshake to $IP:$PORT completed";;
  *refused*) verdict "L4 TCP (connection refused = RST)" "Host is up but nothing listens on $PORT: nginx stopped / listening on another port / wrong port in URL. On edge: scripts/diagnose-edge.sh";;
  *) verdict "L3/L4 (timeout, no SYN-ACK)" "Packets dropped: host off, wrong IP, or a firewall (pf) dropping $PORT. Check pfctl -s info on $IP";;
esac

hdr 5 "TLS - handshake, certificate chain, name match"
CA="$ROOT/tls/rootCA.pem"; CAOPT=""; [ -f "$CA" ] && CAOPT="-CAfile $CA"
TLS="$(echo | openssl s_client -connect "$IP:$PORT" -servername "$NAME" $CAOPT 2>&1)"
info "$(echo "$TLS" | grep -m1 -E '^ *Protocol|New, ' )"
info "subject: $(echo "$TLS" | openssl x509 -noout -subject 2>/dev/null)"
info "SAN    : $(echo "$TLS" | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative" | tail -1 | xargs)"
info "valid  : $(echo "$TLS" | openssl x509 -noout -enddate 2>/dev/null)"
echo "$TLS" | grep -q 'BEGIN CERTIFICATE' || verdict "TLS (handshake failed)" "TCP is up but no TLS: port speaks plain HTTP? nginx 'ssl' missing? $(echo "$TLS" | grep -m1 -i error)"
CURLV="$(/usr/bin/curl -sv -m 5 -o /dev/null "https://$NAME:$PORT$P" 2>&1)"
if echo "$CURLV" | grep -qiE 'SSL certificate problem|certificate verify failed|no alternative certificate subject|does not match|unable to get local issuer'; then
  verdict "TLS (certificate validation)" "$(echo "$CURLV" | grep -m1 -iE 'certificate|SSL') -> CA not trusted on this Mac, wrong cert on edge, SAN missing $NAME, or expired"
fi
ok "certificate trusted and matches $NAME (curl, no -k)"

hdr 6 "HTTP / application - what does the edge return?"
R="$(/usr/bin/curl -sS -m 6 -D - -o /tmp/cn-diag-body "https://$NAME:$PORT$P" 2>&1 | tr -d '\r')"
CODE="$(echo "$R" | awk 'NR==1{print $2}')"
info "$(echo "$R" | grep -iE '^HTTP/|^x-backend|^x-edge|^server' | tr '\n' ' ')"
info "body: $(head -c 120 /tmp/cn-diag-body 2>/dev/null)"
EH="$(/usr/bin/curl -s -m 3 -o /dev/null -w '%{http_code}' "https://$NAME:$PORT/edge-health")"
info "edge's own /edge-health (no backend involved): HTTP $EH"
case "$CODE" in
  200|304) ok "HTTP $CODE - service healthy end-to-end";;
  502|504) verdict "Backend / upstream (behind the edge)" "DNS+TCP+TLS to the edge are fine; nginx cannot reach ANY backend ($CODE). Check backends running, ports 3001/3002, upstream IPs in nginx.conf, pf on backends. On edge: scripts/diagnose-edge.sh";;
  404) verdict "Application (path)" "Edge+backend reachable but path $P unknown, or wrong server_name/location";;
  *) verdict "Application/HTTP (status ${CODE:-none})" "Read the headers above; check /tmp/nginx-cn-error.log on the edge";;
esac
hdr 7 "Backend pool - are BOTH backends serving? (failover can hide a dead backend)"
SEEN=""; for i in 1 2 3 4 5 6; do b="$(/usr/bin/curl -s -m 4 -o /dev/null -D - "https://$NAME:$PORT$P" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-backend"{print $2}')"; SEEN="$SEEN${b:--}"; done
info "6 requests -> X-Backend: $SEEN"
case "$SEEN" in
  *A*B*|*B*A*) ok "both backends serving"; printf '\n\033[1;32m==> ALL LAYERS OK end-to-end\033[0m\n';;
  *) M="A"; case "$SEEN" in *A*) M="B";; esac
     verdict "Backend tier DEGRADED (behind the edge)" "Only $(echo "$SEEN" | tr -d '-' | cut -c1) answers: nginx is failing over around Backend $M. Users see 200s, but redundancy is gone. Check Backend $M process/port, nginx upstream line (port typo?), pf on the backend. On Mac 2: scripts/diagnose-edge.sh (shows TCP/HTTP to each upstream) + /tmp/nginx-cn-error.log";;
esac
