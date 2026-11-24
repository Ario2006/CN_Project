#!/usr/bin/env bash
# Step 9 / Ext A: backup DNS resolver keeps names resolving when the primary DNS dies
source "$(dirname "$0")/../scripts/lib.sh"
say "Two resolvers with the SAME records: primary Mac 1 ($MAC1_IP), backup Mac 3 ($BACKUP_DNS_IP). Clients list both, in order."
on mac3 "scripts/dns-ctl.sh backup status"
run "diff <(grep record '$ROOT/dns/team-dnsmasq.conf') <(grep record '$ROOT/dns/team-dnsmasq-backup.conf') && echo 'records identical'"
run "'$ROOT/scripts/set-client-dns.sh' both"
run "'$ROOT/scripts/dns-failover-check.sh' --flush"; pause
say "Now the primary DNS service dies (dnsmasq stopped on Mac 1)."
run "'$ROOT/scripts/dns-ctl.sh' primary stop"
run "'$ROOT/scripts/dns-failover-check.sh' --flush"
say "Primary DOWN, backup answered (SERVER line = Mac 3), and HTTPS still works. Mac 3's log proves who answered:"
on mac3 "grep 'query\[A\] $APP' /tmp/dnsmasq-cn-backup.log | tail -n 3"
pause
say "DNS failure vs app failure: no DNS = 'Could not resolve host', no TCP at all. Backends down = name resolves, TLS works, edge returns 502."
run "'$ROOT/scripts/dns-ctl.sh' primary start"
