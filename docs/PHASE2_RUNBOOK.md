# Phase 2 Runbook - Harden, Recover, Troubleshoot

Run this from **Mac 1 (Aryan)**, with one terminal tab SSH'd into each teammate's Mac.
Phase 2 builds on the Phase 1 network. Nothing is rebuilt from scratch.

## Role map for Phase 2

| Mac | Person | Phase 1 role | Added in Phase 2 |
|---|---|---|---|
| 1 | Aryan | Primary DNS (dnsmasq) + client | Observer client for Ext B/E, TTL probe |
| 2 | Ranajeet | Primary edge nginx (TLS + LB) | nginx with passive health checks (Ext D) |
| 3 | Abhijeet | Backend A :3001 | **Backup DNS** (Ext A) + pf isolation (Ext C) |
| 4 | Ankita | Backend B :3002 + client | **Standby edge nginx** (Ext E) + pf isolation (Ext C) + Ext A client |

These come from `BACKUP_DNS_IP` and `STANDBY_EDGE_IP` in `env.sh`. To swap roles, change those two lines and re-render.

Why this split: the doc names Mac 1 and Mac 4 as clients. The backup DNS can't run on the client that tests it (Mac 4) or on Mac 1, so it goes on Mac 3. The standby edge goes on Mac 4 and is observed from Mac 1.

## New and changed files

| File | Purpose |
|---|---|
| `env.sh` (Phase 2 block) | `BACKUP_DNS_IP`, `STANDBY_EDGE_IP`, `APP_RECORD_IP`, `DNS_TTL=30`, `CERT_DIR` |
| `scripts/render-configs.sh` | Now also renders `dns/team-dnsmasq-backup.conf`, `nginx/nginx-standby.conf` and `firewall/backend-{A,B}.pf` |
| `dns/*.conf` | Uses `host-record` (TTL 30 s, clean AAAA no-data). `app` can move; `api` always stays on Mac 2 as a control record |
| `nginx/nginx.conf` | Adds the `X-Edge: primary/standby` header, `/edge-health`, passive health checks (`max_fails=1 fail_timeout=10s`, `proxy_next_upstream ... http_502/503/504`, `proxy_connect_timeout 1s`) and a log line that shows every upstream tried |
| `scripts/dns-ctl.sh` | `primary or backup` with `start, stop, restart, status or log` (runs in the background, so it's safe over SSH) |
| `scripts/edge-ctl.sh` | `primary or standby` with `start, stop, reload, test, status or log` |
| `scripts/backend-ctl.sh` | `A or B` with `start, stop, restart, status or log` |
| `scripts/set-client-dns.sh` | `both, primary, reset or flush`: sets a client's resolver list |
| `scripts/dns-set-app.sh` | Moves `app.<domain>` to a new IP and restarts this Mac's dnsmasq |
| `scripts/firewall.sh` | `apply, status or rollback`: pf isolation in its own anchor, with an automatic rollback copy |
| `scripts/watch-requests.sh` | One request per second: status, X-Backend, X-Edge, and the IP actually connected to |
| `scripts/ttl-watch.sh` | Client cache vs authoritative answer every 2 s (shows STALE) |
| `scripts/ttl-cache-probe.sh` | Local caching resolver, so dig shows the TTL counting down 30 to 0 |
| `scripts/dns-failover-check.sh` | Ext A: which resolver is up and which one the client actually used |
| `scripts/diagnose.sh` / `diagnose-edge.sh` | Ext F: bottom-up layer-by-layer diagnosis |

---

## 0. Pre-flight (first 20 minutes)

### 0.1 Each teammate does this on their own Mac
1. Join the **same Wi-Fi** as everyone else.
2. Go to **System Settings, then General, then Sharing, then Remote Login: ON**. Allow access for their own user.
3. Tell Aryan the output of: `whoami; ipconfig getifaddr en0; ls -d ~/*/CN_Project ~/Desktop/*/CN_Project 2>/dev/null`. That gives their username, their IP and where the repo lives.

### 0.2 Aryan: SSH sessions (one tab per Mac)
```bash
ssh-copy-id <user>@<ip>       # once per Mac, optional; avoids retyping the login password
ssh <user>@<ip>               # INTERACTIVE session: login shell, so Homebrew PATH works
cd <repo path> && sudo -v     # the owner types their sudo password; cached for about 5 min
```
> Use interactive sessions, not `ssh host 'cmd'`. One-shot commands don't load `~/.zprofile`, so `brew`, `nginx` and `dnsmasq` aren't on PATH.
> `sudo` asks for **the owner's** password. Let them type it themselves.
> Our scripts run services in the background with log files, so closing the SSH tab doesn't kill them.

### 0.3 Update IPs (DHCP changes them; the env.sh IPs are already stale)
On Mac 1:
```bash
vi env.sh                      # MAC1_IP..MAC4_IP (and GATEWAY/SUBNET/NETMASK if on a different Wi-Fi)
scripts/render-configs.sh      # re-renders DNS, nginx and pf files from env.sh
git add -A && git commit -m "Phase 2: IPs for <date>" && git push
```
On every other Mac: `git pull`.

### 0.4 Install what's new
```bash
# Mac 3 (backup DNS):
brew install dnsmasq
# Mac 4 (standby edge):
brew install nginx && mkdir -p "$(brew --prefix)/etc/nginx/certs"
```

### 0.5 Copy the edge certificate and key to the standby edge (Mac 2 to Mac 4)
The certificate is bound to the **name** `app.<domain>` (SAN), not to an IP. Any edge holding the key can serve it, which is why a DNS cutover works without reissuing anything.
```bash
# run on Mac 2 (Ranajeet), needs Remote Login on Mac 4:
scp /opt/homebrew/etc/nginx/certs/edge.pem /opt/homebrew/etc/nginx/certs/edge-key.pem <ankita>@<MAC4_IP>:/opt/homebrew/etc/nginx/certs/
# then on Mac 4:
chmod 600 /opt/homebrew/etc/nginx/certs/edge-key.pem
```
Never commit `edge-key.pem`. After the evaluation, delete it from Mac 4.

### 0.6 Bring Phase 1 back up and verify the baseline
| Where | Command |
|---|---|
| Mac 3 | `scripts/backend-ctl.sh A start` |
| Mac 4 | `scripts/backend-ctl.sh B start` |
| Mac 2 | `scripts/edge-ctl.sh primary start` (uses the **new** nginx.conf) |
| Mac 1 | `scripts/dns-ctl.sh primary start` |
| Mac 1, Mac 4 (clients) | `scripts/set-client-dns.sh primary` |
| Mac 1 or Mac 4 | `scripts/verify-lan.sh`, `scripts/verify-dns.sh`, `scripts/verify-edge.sh` |

Expected: dig gives Mac 2's IP, the X-Backend header alternates A, B, A, B, and you also see `X-Edge: primary`.
Check the CA is still trusted on every client: `/usr/bin/curl -sI https://app.teamTeamCN.test/api/status` with **no `-k`**.

---

## Ext D: High-availability failover (do this first; it only needs the new nginx.conf)

**Goal:** nginx detects a dead backend and routes only to the healthy one. When the backend comes back, balancing resumes.

| Step | Where | Command | Expect |
|---|---|---|---|
| 1 | Mac 2 | `scripts/edge-ctl.sh primary log` (leave it open) | live access log |
| 2 | Mac 1 | `scripts/watch-requests.sh 0 1` (leave it open) | alternating A/B, all 200 |
| 3 | Mac 3 | `scripts/backend-ctl.sh A stop` (note the time) | |
| 4 | Mac 1 watch | | **every line 200 and B**; no errors |
| 5 | Mac 2 log | | first failing request: `upstream=<A>:3001, <B>:3002 upstream_status=502, 200`. Error log: `connect() failed (61: Connection refused)` and `upstream server temporarily disabled` |
| 6 | Mac 3 | `scripts/backend-ctl.sh A start` | |
| 7 | Mac 1 watch | | within 10 s (`fail_timeout`) the A/B alternation resumes |

What it means:
- **Passive health check.** Open-source nginx learns that a backend is down from real traffic. A connect error makes it retry the same request on B (`proxy_next_upstream`), so the client never sees the error. `max_fails=1` marks A as down for `fail_timeout=10s`. After that, one real request probes A again.
- Active health checks (probing `/health` every N seconds) exist only in nginx Plus, or with the third-party `nginx_upstream_check_module`. The cloud equivalent is ALB target-group health checks.
- Optional harder case: turn off Mac 3's Wi-Fi instead of stopping the process. Now there's no RST, only a 1 s connect timeout per attempt, then B answers.

**SPOF statement (must say this):** the edge nginx on Mac 2 is still a single point of failure, along with the Wi-Fi AP/LAN and Mac 2 as the only holder of the CA key. Ways to eliminate it:
1. Two edges sharing a **floating virtual IP** with VRRP/keepalived (active-passive, takes about 1 s).
2. Two edges behind **DNS with multiple A records plus health-checked DNS** (Route 53 failover routing).
3. Anycast, or a managed multi-AZ load balancer (AWS ALB is itself redundant across AZs).

Ext E shows the manual DNS version of option 2.

**Evidence `evidence/12_HA_FAILOVER/`:** `12_HA_both_up.png` (watch output A/B), `12_HA_A_down_all_B.png`, `12_HA_nginx_log_retry.png` (the `502, 200` line plus the error log), `12_HA_A_back_resumes.png`, `12_HA_upstream_config.png` (`sed -n '/upstream/,/}/p' nginx/nginx.conf`). Optional pcap on Mac 2: `sudo tcpdump -i en0 -w /tmp/12_ha.pcap 'tcp port 3001 or tcp port 3002'`. It shows a SYN to :3001 answered by RST, then a SYN to :3002.

---

## Ext C: Service isolation (pf firewall on the backends)

**Goal:** only Mac 2 can reach :3001 and :3002. Clients can't connect directly. Restore everything afterwards.

| Step | Where | Command | Expect |
|---|---|---|---|
| 1 | Mac 1 | `nc -vz -G 3 <MAC3_IP> 3001; nc -vz -G 3 <MAC4_IP> 3002` | **succeeded** (before) |
| 2 | Mac 3 | `scripts/firewall.sh apply` | rollback copy saved in `firewall/backup/...`, rules listed, `Status: Enabled` |
| 3 | Mac 4 | `scripts/firewall.sh apply` | same for :3002 |
| 4 | Mac 1 | `nc -vz -G 3 <MAC3_IP> 3001` and `curl -m 5 http://<MAC3_IP>:3001/api/status` | **timed out** (dropped, not refused) |
| 5 | Mac 2 | `nc -vz <MAC3_IP> 3001; curl -s http://<MAC4_IP>:3002/api/status` | **succeeded** and JSON (the edge is allowed) |
| 6 | Mac 1 | `scripts/verify-edge.sh` | the service still works through the edge, A/B alternating |
| 7 | Mac 3 / Mac 4 | `scripts/firewall.sh status` | anchor rules plus live states, which show Mac 2's connections |
| 8 | Mac 3 / Mac 4 | `scripts/firewall.sh rollback` | anchor flushed, our pf reference released |
| 9 | Mac 1 | repeat step 1 | succeeded again (restored) |

Viva points:
- **Why pf rather than the macOS Application Firewall?** The Application Firewall filters per app ("allow python3?"). It can't say "only from IP X to port Y". pf is a stateful L3/L4 packet filter.
- **Why `block drop` rather than `block return`?** Drop means the client gets no reply and times out, which hides that the port exists. Return sends a RST, which looks the same as "connection refused".
- **Why do responses to Mac 2 still flow?** `keep state`: pf records the allowed connection, and the return packets match that state.
- **Why not edit /etc/pf.conf?** The stock pf.conf already evaluates every anchor under `com.apple/*`. Our rules live in `com.apple/250.CNIsolation`, so rollback means flushing one anchor. The original pf.conf is copied to `firewall/backup/<host>-<time>/` as the rollback copy.
- Cloud equivalent: security groups ("backend SG allows 3001 only from the ALB's SG").
- Capture idea: run `sudo tcpdump -i en0 'tcp port 3001'` on Mac 3. The client's SYNs arrive (BPF sees packets before pf) and get no SYN-ACK, while Mac 2's SYNs are answered.

**Evidence `evidence/11_ISOLATION/`:** `11_ISO_rules.png`, `11_ISO_client_blocked.png`, `11_ISO_edge_allowed.png`, `11_ISO_service_still_works.png`, `11_ISO_rollback_restored.png`. Also commit `firewall/backend-*.pf` and `firewall/backup/` (the rollback copy).

---

## Ext A: Backup DNS resolver

**Goal:** a second resolver (Mac 3) holds the same records. Clients list both servers. Stop the primary and resolution keeps working.

| Step | Where | Command | Expect |
|---|---|---|---|
| 1 | Mac 3 | `scripts/dns-ctl.sh backup start` | RUNNING, answers app with Mac 2's IP |
| 2 | Mac 3 | `diff <(grep record dns/team-dnsmasq.conf) <(grep record dns/team-dnsmasq-backup.conf)` | no difference: same records |
| 3 | Mac 4 (and Mac 1) | `scripts/set-client-dns.sh both` | `networksetup: <MAC1> <MAC3>` |
| 4 | Mac 4 | `scripts/dns-failover-check.sh --flush` | both servers UP; SERVER = Mac 1 |
| 5 | Mac 3 | `scripts/dns-ctl.sh backup log` (leave it open) | |
| 6 | Mac 1 | `scripts/dns-ctl.sh primary stop` (note the time) | |
| 7 | Mac 4 | `scripts/dns-failover-check.sh --flush` | PRIMARY DOWN, BACKUP UP; `SERVER: <MAC3_IP>#53`; curl gives 200 |
| 8 | Mac 3 log | | `query[A] app... from <MAC4_IP>`: the backup really answered |
| 9 | Mac 4 | `curl` / Safari to `https://app.teamTeamCN.test` | works |
| 10 | Mac 1 | `scripts/dns-ctl.sh primary start` | restore |

> Flush before testing (`--flush`). Otherwise the client answers from its 30 s cache and you prove nothing.
> dig output during failover often shows `communications error to <MAC1>#53: connection refused`, then the answer from Mac 3. That's the failover happening: Mac 1 sent back ICMP port-unreachable, so the client moved to the next server.

**DNS failure vs application failure (say this):**

| | DNS service down (both resolvers) | Application down (both backends) |
|---|---|---|
| dig | timeout or no servers reached | answers with Mac 2's IP |
| TCP/TLS to the edge | never attempted, because there's no IP | succeeds |
| curl | `Could not resolve host` | `HTTP 502 Bad Gateway` |
| Layer | name resolution (directory) | backend, behind the edge |

Packet proof (optional): on Mac 4, `sudo tcpdump -i en0 -w /tmp/09_dnsfail.pcap 'udp port 53 or icmp'`. It shows a query to Mac 1, then ICMP port unreachable, then a query to Mac 3 and the answer.

**Evidence `evidence/09_BACKUP_DNS/`:** `09_DNS_backup_config.png`, `09_DNS_client_two_resolvers.png`, `09_DNS_both_up.png`, `09_DNS_primary_stopped.png`, `09_DNS_resolved_via_backup.png`, `09_DNS_backup_server_log.png`, and optionally `09_DNS_failover.pcap`.

---

## Ext B: DNS TTL and controlled record change

**Goal:** TTL 30 s is visible. After the record changes, the client keeps the old answer until the TTL expires. A manual flush makes the change take effect immediately.

Setup: Mac 1 uses only itself (`scripts/set-client-dns.sh primary`), so only one server is involved.

| Step | Where | Command | Expect |
|---|---|---|---|
| 1 | Mac 1 | `dig app.teamTeamCN.test` | ANSWER `app... 30 IN A <MAC2_IP>`; **30 is the TTL** |
| 2 | Mac 1 tab A | `scripts/ttl-watch.sh` | CACHED = SERVER = MAC2 (in sync) |
| 3 | Mac 1 tab B (optional, most visual) | `scripts/ttl-cache-probe.sh` | TTL counting down 30, 28, 26... |
| 4 | Mac 1 tab C | `scripts/dns-set-app.sh mac3` (note the time; any other IP works) | `app ... <MAC2> -> <MAC3>` |
| 5 | ttl-watch | | SERVER shows the new IP at once; CACHED stays on the old IP with **STALE** for the rest of its TTL (up to 30 s), then shows the new IP |
| 6 | ttl-cache-probe | | the old IP is served until the TTL reaches 0, then the new IP with TTL 30 again |
| 7 | Mac 1 | `scripts/dns-set-app.sh primary`, then **immediately** `scripts/set-client-dns.sh flush` | ttl-watch is in sync on the very next line: flushing skips the wait |

How long it stays stale depends on how much of the 30 s was left when you changed the record. The cache timer started when the client last fetched the record, not when you made the change. That's a viva point.

**Production meaning (one paragraph for the report):** before a migration, lower the TTL (say from 3600 to 60) at least one old TTL ahead of time, because caches still hold the record under the old TTL. Then switch the record. Keep the old endpoint serving for at least one TTL while caches drain. Once traffic has moved, raise the TTL again. A low TTL means faster cutover but more queries to the DNS servers. Some clients, such as JVMs and browsers with their own caches, ignore or stretch TTLs, so the old endpoint should run longer than the TTL.

**Evidence `evidence/10_TTL/`:** `10_TTL_dig_ttl30.png`, `10_TTL_stale_after_change.png` (STALE lines), `10_TTL_expired_new_ip.png`, `10_TTL_countdown_probe.png`, `10_TTL_flush_immediate.png`, `10_TTL_server_log_change.png`.

---

## Ext E: Controlled edge migration (DNS-based cutover)

**Goal:** a standby nginx on Mac 4 with the same config. Point `app` at it. Clients with a cached answer keep hitting Mac 2 for a short while, and new lookups go to the standby.

| Step | Where | Command | Expect |
|---|---|---|---|
| 1 | Mac 4 | `scripts/edge-ctl.sh standby start` | config test OK, `edge-health: {"edge":"standby"...}` |
| 2 | Mac 4 | `diff nginx/nginx.conf nginx/nginx-standby.conf` | differences only in comments and the `X-Edge` name: same upstreams, same TLS |
| 3 | Mac 1 | `scripts/set-client-dns.sh both` (Mac 1 is the observer) | |
| 4 | Mac 1 tab A | `scripts/watch-requests.sh 0 1` | `X-Edge primary`, CONNECTED-TO `<MAC2> (Mac2-primary)` |
| 5 | Mac 1 tab B | `scripts/ttl-watch.sh` | in sync |
| 6 | Mac 1 | `scripts/dns-set-app.sh standby` | `app: <MAC2> -> <MAC4>` |
| 7 | Mac 3 | `scripts/dns-set-app.sh standby` | the backup DNS serves the same new answer |
| 8 | watch | | **for up to 30 s:** still `X-Edge primary` via Mac 2 (cached). **Afterwards:** `X-Edge standby` via `<MAC4> (standby)`. Zero failed requests |
| 9 | Mac 4 (a fresh client) | `scripts/set-client-dns.sh flush; curl -sI https://app.teamTeamCN.test/api/status` | `x-edge: standby` straight away: new lookups go to the standby |
| 10 | Mac 2 | `scripts/edge-ctl.sh primary log` | old-edge traffic drains to zero after the TTL |
| 11 | Mac 2 | only after draining: `scripts/edge-ctl.sh primary stop` | the watch stays at 200 |
| 12 | Rollback | Mac 2 `edge-ctl.sh primary start`; Mac 1 and Mac 3 `dns-set-app.sh primary`; Mac 4 `edge-ctl.sh standby stop` | |

Viva points:
- No new certificate was needed: the SAN names `app.<domain>`, and the client validates the name, not the IP.
- Why keep the old edge running during the TTL? Cached clients still go there. Stopping it early would give them connection errors.
- How is this different from VRRP? A DNS cutover is limited by TTL and caching, takes seconds to minutes, and is controlled by clients. A floating IP moves in about 1 s, is invisible to clients, but only works within one L2 segment.
- The TLS session isn't migrated. Clients do a fresh TCP and TLS handshake with the standby.

**Evidence `evidence/13_EDGE_CUTOVER/`:** `13_EDGE_standby_running.png`, `13_EDGE_config_diff.png`, `13_EDGE_dns_changed.png`, `13_EDGE_cached_still_primary.png`, `13_EDGE_switched_standby.png` (ideally ONE screenshot of the watch output showing the primary-to-standby transition with timestamps), `13_EDGE_fresh_client_standby.png`, `13_EDGE_primary_drained_log.png`.

---

## Ext F: Faculty-injected fault, practice drill

**Method, said out loud each time:** "Start at the bottom. Does the name resolve, by whom, to what? Can I reach that IP? Does TCP connect to the port? Does TLS validate? What HTTP status and which backend?"
Tool: `scripts/diagnose.sh` on the client stops at the first failing layer. `scripts/diagnose-edge.sh` on Mac 2 checks nginx, its config, its certificates and each upstream.

Manual equivalents (be ready to type these without the script):
```bash
scutil --dns | grep nameserver; cat /etc/hosts            # which resolver? any override?
dig app.teamTeamCN.test; dig @<MAC1_IP> app.teamTeamCN.test  # resolution and who answered
ping -c2 <ip>; arp -n <ip>                                  # L3 / L2
nc -vz -G 3 <ip> 443                                        # L4: succeeded / refused / timeout
openssl s_client -connect <ip>:443 -servername app.teamTeamCN.test </dev/null | head -20   # TLS
/usr/bin/curl -v https://app.teamTeamCN.test/api/status     # HTTP status, X-Backend, X-Edge
# on Mac 2:
sudo nginx -t -c $PWD/nginx/nginx.conf; tail /tmp/nginx-cn-error.log
```

### Practice faults (one person injects, another diagnoses with the clock running)

| # | Injected fault (how) | Symptom | Layer | Fix |
|---|---|---|---|---|
| 1 | Client DNS set to 8.8.8.8 (`networksetup -setdnsservers Wi-Fi 8.8.8.8`) | `Could not resolve host` | DNS (client config) | `set-client-dns.sh both` |
| 2 | `/etc/hosts` line `1.2.3.4 app.teamTeamCN.test` on the client | dig is correct but curl goes to the wrong IP and times out | DNS (local override beats DNS) | remove the line and flush |
| 3 | Wrong record: `dns-set-app.sh 10.7.0.250` | resolves, then TCP times out | DNS data (directory has a wrong entry) | `dns-set-app.sh primary` |
| 4 | dnsmasq stopped on both servers | `Could not resolve host` | DNS service | start them |
| 5 | nginx stopped on Mac 2 | resolves, then `Connection refused` (RST) | L4 at the edge | start nginx |
| 6 | nginx `listen 8443` instead of 443 | refused on 443 | L4 (wrong port) | fix and reload |
| 7 | pf on Mac 2 blocking 443 | resolves, then timeout | L3/L4 filter | rollback pf |
| 8 | nginx `ssl_certificate` pointing at a cert without the right SAN, or an untrusted cert | TCP OK, then `SSL: no alternative certificate subject name matches` or `unable to get local issuer` | TLS | correct cert or trust the CA |
| 9 | CA removed from a client's keychain | the same TLS error, only on that client | TLS trust (client side) | re-trust `rootCA.pem` |
| 10 | Upstream port typo (`:3011`) in nginx.conf | 502 only for half the requests, or all of them if both are wrong | upstream / backend | fix and reload; `diagnose-edge.sh` |
| 11 | Both backends stopped | 502, but `/edge-health` gives 200 | backend layer | start backends |
| 12 | Backend bound to 127.0.0.1 (`BIND=127.0.0.1`) | works on that Mac, 502 or refused from Mac 2 | L4 bind address | bind 0.0.0.0 |
| 13 | pf on a backend blocks Mac 2 as well | requests slow by 1 s (connect timeout) then served by the other backend; 504/502 if both are blocked | L3/L4 filter behind the edge | rollback pf |
| 14 | Mac 2's Wi-Fi IP changed (DHCP) | dig gives the old IP, which times out | DNS data is stale | update env.sh, re-render, restart dnsmasq |

Telling them apart quickly:
- **refused** means the host is up but no listener on that port (RST).
- **timeout** means a packet was dropped: host off, wrong IP, or a firewall.
- A **TLS error** means the network is fine and the problem is identity or trust.
- **502** means the edge is fine and the problem is behind it.
- `/edge-health` = 200 while `/api/status` = 502 proves the fault is in the backend tier.

**Evidence `evidence/14_TROUBLESHOOT/`:** a screenshot of `diagnose.sh` for 3 or 4 practice faults, for example `14_TS_wrong_record.png`, `14_TS_nginx_down.png`, `14_TS_cert_san.png`, `14_TS_backends_502.png`.

---

## Final rollback (end of the session)
```bash
# Mac 3/4: scripts/firewall.sh rollback        (if still applied)
# Mac 4  : scripts/edge-ctl.sh standby stop; rm /opt/homebrew/etc/nginx/certs/edge-key.pem   (after the final evaluation)
# Mac 3  : scripts/dns-ctl.sh backup stop
# Mac 1/3: scripts/dns-set-app.sh primary
# clients: scripts/set-client-dns.sh reset     (only once the project is fully done)
```

## Demo-day order (doc section 8, steps 8 and 9)
Step 8: run Ext D live (stop A, watch everything go to B, restart A).
Step 9: run Ext A live (stop the primary DNS, resolve through the backup), then Ext E (cutover with TTL effect). Mention Ext B and Ext C, and show their evidence.
Step 10: Ext F, using `diagnose.sh` and explaining out loud.
