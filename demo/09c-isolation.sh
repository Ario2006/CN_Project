#!/usr/bin/env bash
# Step 9 / Ext C: only the edge (Mac 2) may reach backend ports 3001/3002 (pf), then rollback
source "$(dirname "$0")/../scripts/lib.sh"
say "Before: a client can reach the backends directly (bypassing the edge)."
run "nc -vz -G 3 $MAC3_IP $BACKEND_A_PORT; nc -vz -G 3 $MAC4_IP $BACKEND_B_PORT"; pause
say "Apply pf isolation on both backends (rules in their own anchor; rollback copy saved first)."
on mac3 "scripts/firewall.sh apply"
on mac4 "scripts/firewall.sh apply"
say "Client -> backend: dropped (timeout)."
run "nc -vz -G 3 $MAC3_IP $BACKEND_A_PORT; nc -vz -G 3 $MAC4_IP $BACKEND_B_PORT"
say "Edge -> backend: allowed."
on mac2 "nc -vz -G 3 $MAC3_IP $BACKEND_A_PORT; nc -vz -G 3 $MAC4_IP $BACKEND_B_PORT"
say "Service through the edge still works:"
run "'$ROOT/scripts/watch-requests.sh' 4 1"; pause
say "Rollback (restore the original configuration)."
on mac3 "scripts/firewall.sh rollback"
on mac4 "scripts/firewall.sh rollback"
run "nc -vz -G 3 $MAC3_IP $BACKEND_A_PORT; nc -vz -G 3 $MAC4_IP $BACKEND_B_PORT"
