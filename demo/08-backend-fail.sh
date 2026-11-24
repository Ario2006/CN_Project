#!/usr/bin/env bash
# Step 8 / Ext D: stop Backend A, service continues on B, A returns -> balancing resumes
source "$(dirname "$0")/../scripts/lib.sh"
say "Both backends up: A and B alternate."
run "'$ROOT/scripts/watch-requests.sh' 4 1"; pause
say "Stopping Backend A on Mac 3."
on mac3 "scripts/backend-ctl.sh A stop"
run "'$ROOT/scripts/watch-requests.sh' 8 1"
say "Every request 200 from B. Connecting to A failed (504 = no answer within proxy_connect_timeout 1s, because Mac 3's firewall drops SYNs to a closed port; without a firewall it would be an instant RST/refused). nginx retried the SAME request on B (proxy_next_upstream) and marked A down for fail_timeout=10s. Log: upstream=A, B  upstream_status=504, 200."
on mac2 "grep -E 'upstream=[^ ]+, ' /tmp/nginx-cn-access.log | tail -n 2; grep -E 'refused|timed out|temporarily disabled' /tmp/nginx-cn-error.log | tail -n 3"
pause
say "Restarting Backend A."
on mac3 "scripts/backend-ctl.sh A start"
run "'$ROOT/scripts/watch-requests.sh' 14 1"
say "After at most 10 s nginx tries A again with real traffic -> A, B alternate again. Remaining single point of failure: the edge (Mac 2) itself."
