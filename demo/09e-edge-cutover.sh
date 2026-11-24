#!/usr/bin/env bash
# Step 9 / Ext E: standby edge on Mac 3, DNS cutover, cached clients stay on the old edge until TTL expiry
source "$(dirname "$0")/../scripts/lib.sh"
say "Standby nginx on Mac 3 with the SAME config (only the X-Edge name differs). Same certificate: it names the domain, not an IP."
on mac3 "scripts/edge-ctl.sh standby start"
run "diff '$ROOT/nginx/nginx.conf' '$ROOT/nginx/nginx-standby.conf' | grep -E '^[<>]' | grep -vE '^[<>] #'"
run "'$ROOT/scripts/set-client-dns.sh' flush >/dev/null; '$ROOT/scripts/watch-requests.sh' 3 1"; pause
say "Cutover: $APP -> standby ($STANDBY_EDGE_IP) on BOTH DNS servers. Watch X-Edge and CONNECTED-TO."
run "'$ROOT/scripts/dns-set-app.sh' standby"
on mac3 "scripts/dns-set-app.sh standby"
run "'$ROOT/scripts/watch-requests.sh' 40 1"
say "Cached client kept using the primary until its TTL expired, then moved to the standby - zero failed requests. The old edge stays up until it drains."
on mac2 "tail -n 3 /tmp/nginx-cn-access.log"
pause
say "Rollback: point back to the primary, stop the standby."
run "'$ROOT/scripts/dns-set-app.sh' primary"; on mac3 "scripts/dns-set-app.sh primary"
run "'$ROOT/scripts/set-client-dns.sh' flush"; on mac3 "scripts/edge-ctl.sh standby stop"
