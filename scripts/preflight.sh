#!/usr/bin/env bash
# ONE-SCREEN HEALTH CHECK of the whole system, from any client Mac (no SSH needed).
#   scripts/preflight.sh          -> green/red per layer; run before the slot and after every demo
source "$(dirname "$0")/lib.sh"
F=0; fail(){ bad "$*"; F=$((F+1)); }
hdr "This Mac"
[ "$(role)" != unknown ] && ok "$(myip) = $(role) ($(label "$(myip)"))" || fail "$(myip) is not in env.sh -> run scripts/sync.sh after fixing IPs"
hdr "L3 reachability (ping)"
for m in 1 2 3 4; do ip="$(eval echo \$MAC${m}_IP)"; [ "$ip" = "$(myip)" ] && continue
  ping -c1 -t2 "$ip" >/dev/null 2>&1 && ok "Mac$m $ip $(label "$ip")" || fail "Mac$m $ip no ping reply"; done
hdr "DNS"
grep -qi "$DOMAIN" /etc/hosts && fail "/etc/hosts overrides $DOMAIN: $(grep -i "$DOMAIN" /etc/hosts)"
R="$(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ')"
case " $R" in *" $MAC1_IP "*) ok "client resolvers: $R";; *) fail "client resolvers: $R (team DNS missing -> scripts/set-client-dns.sh both)";; esac
for r in $R; do case "$r" in "$MAC1_IP"|"$BACKUP_DNS_IP") ;; *) fail "non-team resolver $r in the list: it answers NXDOMAIN for $DOMAIN and poisons the cache -> scripts/set-client-dns.sh both";; esac; done
P="$(dig +short +time=2 +tries=1 @"$MAC1_IP" "$APP" 2>/dev/null | head -1)"
[ "$P" = "$MAC2_IP" ] && ok "primary $MAC1_IP: $APP -> $P (edge Mac 2)" || fail "primary $MAC1_IP: $APP -> '${P}' (expected $MAC2_IP)"
S="$(dig +short +time=2 +tries=1 @"$BACKUP_DNS_IP" "$APP" 2>/dev/null | head -1)"
[ "$S" = "$MAC2_IP" ] && ok "backup  $BACKUP_DNS_IP: $APP -> $S" || warn "backup $BACKUP_DNS_IP: '${S}' (needed for Ext A: scripts/dns-ctl.sh backup start on Mac 3)"
T="$(dig +time=2 +tries=1 @"$MAC1_IP" "$APP" +noall +answer 2>/dev/null | awk '/IN[[:space:]]+A/{print $2; exit}')"; [ -n "$T" ] && ok "TTL on record: ${T}s"
SYS="$(dscacheutil -q host -a name "$APP" | awk '/ip_address/{print $2; exit}')"
[ "$SYS" = "$MAC2_IP" ] && ok "system resolver (what curl/Safari use): $SYS" || fail "system resolver gives '${SYS}' (flush: scripts/set-client-dns.sh flush)"
hdr "Edge (TCP, TLS, HTTP) by NAME, certificate validated (no -k)"
nc -z -G 2 "$MAC2_IP" "$HTTPS_PORT" 2>/dev/null && ok "TCP $MAC2_IP:$HTTPS_PORT open" || fail "TCP $MAC2_IP:$HTTPS_PORT closed/filtered"
E="$($CURL -sS -m 4 --resolve "$APP:$HTTPS_PORT:$MAC2_IP" "$URL/edge-health" 2>&1)"
case "$E" in *'"ok"'*) ok "TLS trusted + edge alive: $E";; *) fail "edge-health: $E";; esac
SEEN=""; for i in 1 2 3 4; do b="$($CURL -s -m 4 -D - -o /dev/null "$URL/api/status" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-backend"{print $2}')"; SEEN="$SEEN${b:--}"; done
case "$SEEN" in *A*B*|*B*A*) ok "load balancing via name: $SEEN";; *) fail "load balancing via name: $SEEN (expected A and B)";; esac
C="$($CURL -s -m 4 -o /dev/null -w '%{http_code}' -H 'If-None-Match: "phase1-cache-v1"' "$URL/api/cache")"
[ "$C" = 304 ] && ok "conditional GET /api/cache -> 304" || fail "conditional GET -> $C (expected 304)"
hdr "Backends direct (Phase 1: reachable; during Ext C: must time out)"
for t in "$MAC3_IP:$BACKEND_A_PORT:A" "$MAC4_IP:$BACKEND_B_PORT:B"; do IFS=: read -r ip p id <<<"$t"
  nc -z -G 2 "$ip" "$p" 2>/dev/null && ok "Backend $id $ip:$p reachable directly" || warn "Backend $id $ip:$p NOT reachable directly (down, or pf isolation ON)"; done
hdr "Standby edge (Ext E)"
nc -z -G 2 "$STANDBY_EDGE_IP" "$HTTPS_PORT" 2>/dev/null && warn "standby edge $STANDBY_EDGE_IP:$HTTPS_PORT is UP (fine during Ext E only)" || ok "standby edge idle"
echo; [ "$F" = 0 ] && printf '%sALL GREEN%s\n' "$G$B" "$N" || printf '%s%d FAILURE(S)%s\n' "$R$B" "$F" "$N"; exit "$F"
