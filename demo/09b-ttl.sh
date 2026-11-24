#!/usr/bin/env bash
# Step 9 / Ext B: TTL 30 s, record change, cached client keeps the OLD answer until TTL expiry; flush = immediate
source "$(dirname "$0")/../scripts/lib.sh"
say "Our records carry TTL ${DNS_TTL}s - the number after the name in dig's ANSWER section."
run "dig @$MAC1_IP $APP +noall +answer"
run "'$ROOT/scripts/set-client-dns.sh' flush >/dev/null; dscacheutil -q host -a name $APP | grep ip_address"
pause
say "Changing the record on the server: $APP -> Mac 3 ($MAC3_IP). Server answers new at once; this client's cache keeps the old one."
run "'$ROOT/scripts/dns-set-app.sh' mac3"
run "'$ROOT/scripts/ttl-watch.sh' $APP 20"
say "STALE lines = cached answer still valid; it flips when the TTL runs out. Now change back and FLUSH: no waiting."
pause
run "'$ROOT/scripts/dns-set-app.sh' primary"
run "'$ROOT/scripts/set-client-dns.sh' flush"
run "'$ROOT/scripts/ttl-watch.sh' $APP 2"
say "Production: lower the TTL ahead of a migration, switch, keep the old endpoint up for one TTL, raise the TTL again."
