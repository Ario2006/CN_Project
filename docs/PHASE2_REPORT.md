# Phase 2 Final Report: Harden, Recover, Troubleshoot

**Team:** Aryan Kumar (Mac 1), Ranajeet Roy (Mac 2), Abhijeet Kumar (Mac 3), Ankita Thakur (Mac 4)
**Domain:** `teamTeamCN.test` · **Network:** one campus Wi-Fi subnet `10.7.0.0/19` (mask 255.255.224.0, gateway 10.7.0.1) · **Tests run:** 24 Nov 2026
**Topology:** [topology-phase2.png](topology-phase2.png) · **Evidence:** `evidence/09_*` to `evidence/14_*` (index: [evidence-matrix.md](evidence-matrix.md))

## 1. What changed from Phase 1

| Area | Phase 1 | Phase 2 |
|---|---|---|
| DNS | one dnsmasq (Mac 1), `address=` records | primary (Mac 1) + **backup** (Mac 3) with identical `host-record` entries, TTL 30 s; clients list both |
| Edge | one nginx (Mac 2) | primary (Mac 2) + **standby** nginx (Mac 3) with the same config and cert; `X-Edge` header; `/edge-health` endpoint |
| Health checks | `max_fails=1 fail_timeout=5s`, retry on `error timeout` | `fail_timeout=10s`, `proxy_connect_timeout 1s`, retry also on `http_502/503/504`, `proxy_next_upstream_tries 2`; the log records every upstream tried |
| Backend exposure | 3001/3002 reachable from any LAN host | pf anchor: **only Mac 2** may connect, everyone else is dropped; rollback copy kept |
| Operations | manual foreground commands | `scripts/*-ctl.sh`, `preflight.sh`, `reset-baseline.sh`, `diagnose.sh`, `fault.sh`, demo scripts per evaluation step |
| Configuration | `env.sh` + render script | the same single source of truth, plus knobs: `DNS_TTL`, `APP_RECORD_IP`, `EXTRA_RECORDS`, `LB_METHOD`, `HTTPS_PORT`, `FIREWALL_EXTRA_ALLOW` |

Phase 1 configs are preserved in `nginx/phase1/` and `dns/phase1/`.

**Service inventory (24 Nov):**

| Mac | IP | Services |
|---|---|---|
| 1 Aryan | 10.7.20.4 | dnsmasq primary udp/53, client |
| 2 Ranajeet | 10.7.26.115 | nginx primary edge tcp/443 |
| 3 Abhijeet | 10.7.18.174 | Backend A tcp/3001, dnsmasq backup udp/53, nginx standby tcp/443, pf |
| 4 Ankita | 10.7.17.93 | Backend B tcp/3002, pf, client |

## 2. Resilience tests and results

| # | Test | Expected | Observed | Result | Evidence |
|---|---|---|---|---|---|
| A1 | Both resolvers up, client lists both | Mac 1 answers | `SERVER: 10.7.20.4#53` | PASS | 09_DNS_failover_demo.txt |
| A2 | Primary dnsmasq stopped (23:26:11) | backup answers | `SERVER: 10.7.18.174#53`, `PRIMARY DOWN / BACKUP UP`, curl 200 | PASS | 09_DNS_failover_demo.txt |
| B1 | TTL visible | `30 IN A` | `app.teamTeamCN.test. 30 IN A 10.7.26.115` | PASS | 10_TTL_demo.txt |
| B2 | Record moved to Mac 3 (23:28:10) | client stale up to about 30 s | STALE 23:28:10 to 23:28:45, in sync 23:28:47 (about 37 s) | PASS | 10_TTL_demo.txt |
| B3 | Change back + flush | immediate | in sync on the first poll after the flush | PASS | 10_TTL_demo.txt |
| C1 | Mac 1 → Mac 3:3001 with pf on | timeout | `Operation timed out` | PASS | runbook, Ext C |
| C2 | Mac 2 → Mac 3:3001 with pf on | connects | `succeeded` | PASS | runbook, Ext C |
| C3 | Service through the edge with pf on | 200, A/B | 200 A/B/A/B | PASS | runbook, Ext C |
| C4 | Rollback | direct access back | `succeeded`; rollback copy in `firewall/backup/` | PASS | firewall/backup/ |
| D1 | Backend A stopped (23:24:38) | 100% B, 0 errors | 8/8 200 from B; log `upstream_status=504, 200`, "temporarily disabled" | PASS | 12_HA_failover_demo.txt |
| D2 | A restarted (23:24:51) | A/B resumes after ≤ 10 s | A served again at 23:25:10 | PASS | 12_HA_failover_demo.txt |
| E1 | `app` cut over to standby (23:30:38) | cached client stays on primary ≤ TTL | `X-Edge: primary` until 23:31:09, `standby` from 23:31:10 | PASS | 13_EDGE_cutover_demo.txt |
| E2 | Zero-failure cutover | no failed requests | 43/43 requests 200 (28 primary, 15 standby) | PASS | 13_EDGE_cutover_demo.txt |
| F | 7 injected faults | correct layer | all 7 correctly classified (section 3) | PASS | 14_TS_fault*.txt |

## 3. Troubleshooting findings

| Fault injected | First symptom | Isolation path | Layer | Fix |
|---|---|---|---|---|
| Client DNS set to 8.8.8.8 | `Could not resolve host` | resolver list shows no team DNS | DNS (client config) | `set-client-dns.sh both` |
| `app` record → 10.7.0.250 | curl timeout | resolves OK → not an edge IP → no ARP → TCP timeout | **DNS data** | `dns-set-app.sh primary` on both servers |
| Both dnsmasq stopped | `Could not resolve host` | `dig @Mac1` and `dig @Mac3` both silent | DNS service | start both |
| nginx stopped | curl `Connection refused` | resolves → ping OK → `nc` refused | L4 at the edge | `edge-ctl.sh primary start` |
| nginx on 8443 | refused on 443 | same as above; `diagnose-edge.sh` shows the listen port | L4 (port) | re-render + reload |
| Upstream typo `:3011` | **none visible: all 200** | only `X-Backend: B` in 6 requests → degraded; edge check: `:3011 refused` | upstream config | re-render + reload |
| pf on A blocks the edge | **none visible: all 200** | only B serving; `nc` from Mac 2 to 3001 times out | filter behind the edge | `firewall.sh rollback` |

**Problems we hit while building Phase 2, and what we learned:**
1. **Wrong-domain certificate.** The leaf installed on Mac 2 still named `app.teamX.test`. We reissued it from the same local CA for `app/api.teamTeamCN.test`, so client trust was unchanged.
2. **A public resolver in the client list poisoned our zone.** With `8.8.8.8` listed, macOS cached its NXDOMAIN for `.test` and curl failed even though our servers answered. Rule: clients list only team resolvers. Preflight now checks for this.
3. **The macOS Application Firewall** on Mac 3 drops SYNs to closed ports. A stopped backend therefore shows as a 1 s **connect timeout (504)** rather than an RST, and the first connection to a newly installed nginx timed out until the firewall registered it. We warm it up during bring-up.
4. **Campus resolver 10.5.7.1 was unreachable.** Internet names failed through our dnsmasq, so we made 8.8.8.8 (from DHCP) the upstream with campus as fallback. Our own zone is never forwarded (`local=`).
5. **Failover hides faults.** Faults behind the edge produced no user-visible error, so diagnosis must check the backend distribution, not only the status code.
6. **DHCP changed every IP since Phase 1.** All configs are rendered from `env.sh`, and `set-ip.sh` + `sync.sh` re-deploy in about 2 minutes.

## 4. Learning summary (one paragraph per extension)

**Ext A: Backup DNS.** DNS is a separate service whose failure looks nothing like an application failure. With both resolvers listed, the macOS resolver used Mac 1. When we stopped dnsmasq there, the very next lookup was answered by Mac 3 (`SERVER: 10.7.18.174#53`) and HTTPS kept working. If DNS dies completely, clients cannot even find the edge ("Could not resolve host", no TCP at all). If the backends die, DNS, TCP and TLS still work and the edge returns 502. Redundant resolvers only help if they serve identical data, so both configs are rendered from the same `env.sh`.

**Ext B: TTL.** A TTL is the authoritative server's promise that an answer may be reused for N seconds. After we moved `app`, the server answered with the new IP at once, but the client kept the cached old IP for about 37 s, roughly one TTL counted from its last lookup. A manual flush skipped the wait. In production you lower the TTL well ahead of a migration (the old TTL still governs existing caches), switch, keep the old endpoint alive for at least one TTL, then raise the TTL again. A low TTL buys agility at the cost of more queries and more dependence on DNS availability.

**Ext C: Service isolation.** We loaded pf rules into a dedicated anchor so each backend accepts TCP on its port only from Mac 2. A client's direct attempt timed out (SYN silently dropped, revealing nothing), while the edge connected and users saw no change. This turns "clients only talk to the edge" from a convention into an enforced rule, the same idea as a cloud security group that admits only the load balancer. Using an anchor plus a saved copy of the original configuration made the rollback a single command.

**Ext D: High availability.** Open-source nginx detects failure passively from real traffic. When Backend A stopped, the connection attempt failed within `proxy_connect_timeout` (1 s), nginx retried the same request on B (`proxy_next_upstream`), and it marked A down for `fail_timeout` (10 s), so the client saw only 200s. When A came back, nginx probed it after the timeout and round-robin resumed by itself. The remaining single point of failure is the edge itself, plus the Wi-Fi LAN. Removing it needs a second edge and a way to move clients: a floating VIP (VRRP/keepalived), health-checked DNS failover, or a managed multi-AZ load balancer.

**Ext E: Edge migration.** We ran an identical nginx on Mac 3 and moved `app` to it on both DNS servers. Because the certificate binds to the name, not the IP, the standby presented a valid certificate without reissuing anything. The observing client kept using the primary edge for about 31 s (its cached TTL), then switched to the standby, and all 43 requests succeeded. We kept the old edge running until its traffic drained. That's the essence of a DNS-based cutover: slower and client-cache-dependent compared with a floating IP, but it works across networks.

**Ext F: Troubleshooting.** Diagnosing bottom-up (name, IP, TCP port, TLS, HTTP, backend pool) turns "the site is broken" into one specific layer within a minute. The discriminators we relied on: no resolution means DNS; a resolved but wrong IP means DNS data; refused means nothing is listening; timeout means a dropped packet (host down, wrong IP, firewall); a certificate error means identity or trust; 502/504 with a healthy `/edge-health` means the backend tier. A failover that only ever answers from one backend means degraded redundancy.
