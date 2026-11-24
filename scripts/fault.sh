#!/usr/bin/env bash
# Ext F practice: inject a known fault, let a teammate diagnose it, then undo.
#   scripts/fault.sh list
#   scripts/fault.sh inject <n>      scripts/fault.sh undo <n>
# Run from Mac 1: faults on Mac 2/3 are applied over SSH via on().
source "$(dirname "$0")/lib.sh"
A="${1:-list}"; NUM="${2:-}"
list() { cat <<'L'
 1  client uses wrong DNS (8.8.8.8)             [Mac 1]  layer: DNS client config
 2  DNS record points to a wrong IP (10.7.0.250)[Mac 1]  layer: DNS data
 3  both DNS servers stopped                    [Mac 1+3] layer: DNS service
 4  nginx stopped on the edge                   [Mac 2]  layer: L4 (refused)
 5  nginx listens on 8443 instead of 443        [Mac 2]  layer: L4 port
 6  pf on the edge drops 443                    [Mac 2]  layer: L3/L4 filter (timeout)
 7  upstream port typo for Backend A (3011)     [Mac 2]  layer: upstream (half the requests retried / 502 if both)
 8  both backends stopped                       [Mac 3+4] layer: backend (502)
 9  Backend A bound to 127.0.0.1 only           [Mac 3]  layer: L4 bind address
10  pf on Backend A blocks the edge too         [Mac 3]  layer: filter behind the edge
11  /etc/hosts override on the client           [Mac 1]  layer: local name override (manual)
L
}
PF_ANCHOR="com.apple/250.CNIsolation"
case "$A:$NUM" in
  list:*) list ;;
  inject:1) run "sudo networksetup -setdnsservers $WIFI_SERVICE 8.8.8.8; sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder" ;;
  undo:1)   run "scripts/set-client-dns.sh both" ;;
  inject:2) run "scripts/dns-set-app.sh 10.7.0.250"; on mac3 "scripts/dns-set-app.sh 10.7.0.250"; run "scripts/set-client-dns.sh flush" ;;
  undo:2)   run "scripts/dns-set-app.sh primary"; on mac3 "scripts/dns-set-app.sh primary"; run "scripts/set-client-dns.sh flush" ;;
  inject:3) run "scripts/dns-ctl.sh primary stop"; on mac3 "scripts/dns-ctl.sh backup stop"; run "scripts/set-client-dns.sh flush" ;;
  undo:3)   run "scripts/dns-ctl.sh primary start"; on mac3 "scripts/dns-ctl.sh backup start" ;;
  inject:4) on mac2 "scripts/edge-ctl.sh primary stop" ;;
  undo:4)   on mac2 "scripts/edge-ctl.sh primary start" ;;
  inject:5) on mac2 "HTTPS_PORT=8443 scripts/render-configs.sh nginx && scripts/edge-ctl.sh primary reload" ;;
  undo:5)   on mac2 "scripts/render-configs.sh nginx && scripts/edge-ctl.sh primary reload" ;;
  inject:6) on mac2 "echo 'block drop in quick proto tcp from any to any port $HTTPS_PORT' | sudo pfctl -a $PF_ANCHOR -f - 2>/dev/null; sudo pfctl -E 2>&1 | awk '/Token/{print \$3}' > /tmp/cn-pf-token" ;;
  undo:6)   on mac2 "scripts/firewall.sh rollback" ;;
  inject:7) on mac2 "BACKEND_A_PORT=3011 scripts/render-configs.sh nginx && scripts/edge-ctl.sh primary reload" ;;
  undo:7)   on mac2 "scripts/render-configs.sh nginx && scripts/edge-ctl.sh primary reload" ;;
  inject:8) on mac3 "scripts/backend-ctl.sh A stop"; on mac4 "scripts/backend-ctl.sh B stop" ;;
  undo:8)   on mac3 "scripts/backend-ctl.sh A start"; on mac4 "scripts/backend-ctl.sh B start" ;;
  inject:9) on mac3 "scripts/backend-ctl.sh A stop && cd backend && (BACKEND_ID=A PORT=$BACKEND_A_PORT BIND=127.0.0.1 nohup python3 server.py >> /tmp/cn-backend-A.log 2>&1 </dev/null &) ; sleep 1" ;;
  undo:9)   on mac3 "scripts/backend-ctl.sh A restart" ;;
  inject:10) on mac3 "echo 'block drop in quick proto tcp from any to any port $BACKEND_A_PORT' | sudo pfctl -a $PF_ANCHOR -f - 2>/dev/null; sudo pfctl -E 2>&1 | awk '/Token/{print \$3}' > /tmp/cn-pf-token" ;;
  undo:10)  on mac3 "scripts/firewall.sh rollback" ;;
  inject:11) echo "Manual: echo '10.7.0.250 $APP' | sudo tee -a /etc/hosts; sudo dscacheutil -flushcache" ;;
  undo:11)  echo "Manual: sudo sed -i '' '/$APP/d' /etc/hosts; sudo dscacheutil -flushcache" ;;
  *) echo "usage: fault.sh list | inject <n> | undo <n>"; list; exit 1 ;;
esac
[ "$A" = inject ] && echo ">> fault $NUM injected at $(date +%T). Diagnoser: scripts/diagnose.sh   (undo: scripts/fault.sh undo $NUM)"
