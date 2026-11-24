# "Can you show me / change …?" Live recipes for the examiner

Rule: **edit `env.sh`, run `scripts/render-configs.sh`, then restart the service that reads the file.** Never hand-edit the generated `.conf` files.
Restart commands: DNS `scripts/dns-ctl.sh primary restart` (Mac 1) and `ssh mac3 'cd ~/CN_Project && scripts/dns-ctl.sh backup restart'`. Edge: `ssh mac2 'cd ~/CN_Project && scripts/edge-ctl.sh primary reload'`.
For a one-off, put the variable in front: `DNS_TTL=10 scripts/render-configs.sh dns`.
First, in every new terminal: `cd CN_Project && source env.sh` so that `$MAC2_IP`, `$MAC3_IP` and so on work in the commands below.

## DNS
| Ask | Do | Prove |
|---|---|---|
| "Change the TTL to 10 s" | `DNS_TTL=10 scripts/render-configs.sh dns && scripts/dns-ctl.sh primary restart` | `dig app.teamTeamCN.test` shows `10 IN A` |
| "Add a record db.teamX.test to Mac 3" | `EXTRA_RECORDS="db=$MAC3_IP" scripts/render-configs.sh dns && scripts/dns-ctl.sh primary restart` (or put `EXTRA_RECORDS` in env.sh permanently) | `dig +short db.teamTeamCN.test` |
| "Point app at another IP" | `scripts/dns-set-app.sh <ip or mac3 or standby or primary>` (run on Mac 1 **and** on Mac 3) | `dig`, then `scripts/ttl-watch.sh` |
| "Show the DNS server log" | `scripts/dns-ctl.sh primary log` | `query[A] app... from <client>` |
| "Which server did the client use?" | `dig app.teamTeamCN.test \| grep SERVER` | |
| "Show the DNS packets" | `scripts/capture.sh dns evidence/02_DNS/live.pcap 20` (do a dig meanwhile) | UDP src ephemeral port → dst 53 |
| "Use nslookup" | `nslookup app.teamTeamCN.test` | |
| "What if the client uses a public DNS?" | `scripts/fault.sh inject 1`, then `curl` fails, then `scripts/fault.sh undo 1` | "Could not resolve host": .test is private |

## Edge / load balancing
| Ask | Do | Prove |
|---|---|---|
| "Switch to least_conn" | `LB_METHOD=least_conn scripts/render-configs.sh nginx` then reload the edge (on Mac 2) | `grep -A3 'upstream app_pool' nginx/nginx.conf`; requests still served |
| "Make it sticky (ip_hash)" | `LB_METHOD=ip_hash …` same | the same client always gets the same X-Backend |
| "Back to round-robin" | `scripts/render-configs.sh nginx` and reload | A/B alternate |
| "Use port 8443" | `HTTPS_PORT=8443 scripts/render-configs.sh nginx` and reload on Mac 2; then `HTTPS_PORT=8443 scripts/watch-requests.sh 4 1` | `https://app…:8443` works |
| "Show the upstream config" | `sed -n '/upstream app_pool/,/}/p' nginx/nginx.conf` | |
| "Show which backend served each request" | on Mac 2: `tail -f /tmp/nginx-cn-access.log` | `upstream=IP:port X-Backend=…` |
| "Show the nginx config is valid" | on Mac 2: `scripts/edge-ctl.sh primary test` | `syntax is ok` |
| "Show the health check settings" | `grep -E 'max_fails|proxy_next_upstream|connect_timeout' nginx/nginx.conf` | |

## TLS
| Ask | Do |
|---|---|
| "Show the certificate / SAN" | `echo \| openssl s_client -connect $MAC2_IP:443 -servername app.teamTeamCN.test 2>/dev/null \| openssl x509 -noout -subject -issuer -dates -text \| grep -A1 'Alternative'` |
| "Prove there's no -k" | `/usr/bin/curl -v https://app.teamTeamCN.test/api/status 2>&1 \| grep -iE 'SSL\|subject\|issuer\|verify'` |
| "Force TLS 1.2 for the classic handshake" | `/usr/bin/curl --tls-max 1.2 -v https://app.teamTeamCN.test/api/status` |
| "Show the TLS handshake live" | `scripts/capture.sh https evidence/07_WIRESHARK/live.pcap 20` + a curl, then open it in Wireshark with filter `tls.handshake` |
| "What if the cert didn't match?" | `/usr/bin/curl -v --resolve wrong.teamTeamCN.test:443:$MAC2_IP https://wrong.teamTeamCN.test/` gives a "no alternative certificate subject name" error |

## Backends / transport
| Ask | Do |
|---|---|
| "Show the backend listens on all interfaces" | on Mac 3: `lsof -nP -iTCP:3001 -sTCP:LISTEN` gives `*:3001` |
| "Hit a backend directly" | `curl -si http://$MAC3_IP:3001/api/status` (diagnosis only) |
| "Show a socket pair" | on Mac 2: `lsof -nP -iTCP -sTCP:ESTABLISHED \| grep -E '3001\|3002\|443'` |
| "Show the TCP handshake" | `scripts/capture.sh https …` then filter `tcp.flags.syn==1` |
| "Wrong port: what happens?" | `nc -vz $MAC2_IP 8443` gives refused (RST) |
| "Refused vs timeout" | refused: `nc -vz $MAC2_IP 8443`. Timeout: `nc -vz -G 3 10.7.0.250 443` |
| "Both backends down" | `scripts/fault.sh inject 8` gives 502, while `/edge-health` = 200. Then `scripts/fault.sh undo 8` |

## Isolation / HA / cutover
| Ask | Do |
|---|---|
| "Block port 3001 for everyone but the edge" | on Mac 3: `scripts/firewall.sh apply`. Show the rules: `scripts/firewall.sh status`. Undo: `scripts/firewall.sh rollback` |
| "Also allow Mac 1" | `FIREWALL_EXTRA_ALLOW="$MAC1_IP" scripts/firewall.sh apply` |
| "Where is the rollback copy?" | `ls firewall/backup/*/`, holding `pf.conf.original` and the rules/status from before |
| "Stop A and show the retry in the log" | `demo/08-backend-fail.sh` |
| "Make the standby the primary" | `scripts/dns-set-app.sh standby` on Mac 1 and Mac 3, with the standby edge running (`demo/09e-edge-cutover.sh`) |
| "What's still a single point of failure?" | The active edge and the Wi-Fi LAN/AP. Fix: VRRP floating IP, health-checked DNS, or a managed multi-AZ LB |

## Emergency
- Anything weird: `scripts/preflight.sh`, then `scripts/reset-baseline.sh all`
- IPs changed: `scripts/set-ip.sh auto <mac4-ip>`, then `scripts/sync.sh`, then restart DNS and reload the edge
- The examiner made changes you can't see: `git status` / `git diff` on each Mac. `scripts/render-configs.sh` regenerates every config from `env.sh`
