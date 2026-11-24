# Phase 2 Final Report: Harden, Recover, Troubleshoot

Team: Aryan Kumar (Mac 1), Ranajeet Roy (Mac 2), Abhijeet Kumar (Mac 3), Ankita Thakur (Mac 4)
Domain: `teamTeamCN.test` | Network: `<SUBNET>` | Date of tests: `<DATE>`

> Fill every `<...>` with the real value or observation from the session. Every claim must point to a file in `evidence/09_*` to `evidence/14_*`.

## 1. What changed from Phase 1

| Area | Phase 1 | Phase 2 |
|---|---|---|
| DNS | single dnsmasq on Mac 1, `address=` records | primary (Mac 1) plus **backup** (Mac 3) with identical `host-record` entries, TTL 30 s; clients list both resolvers |
| Edge | one nginx (Mac 2), basic passive failover | primary nginx plus **standby** nginx (Mac 4) with the same config; `X-Edge` header shows which edge answered; `/edge-health` endpoint |
| Health checks | `max_fails=1 fail_timeout=5s`, retry on `error timeout` | `fail_timeout=10s`, retry also on `http_502/503/504`, `proxy_connect_timeout 1s`, `proxy_next_upstream_tries 2`; the log shows every upstream tried |
| Backend exposure | ports 3001/3002 reachable from any LAN host | pf anchor allows **only Mac 2**; others are dropped |
| Operations | manual foreground commands | `scripts/*-ctl.sh` background control, `diagnose.sh` layer-by-layer fault isolation |

Updated IP / service table: `<paste the env.sh IPs of the test day>`

| Mac | IP | Services |
|---|---|---|
| 1 | `<MAC1_IP>` | dnsmasq primary :53/udp, client |
| 2 | `<MAC2_IP>` | nginx primary edge :443 |
| 3 | `<MAC3_IP>` | Backend A :3001, dnsmasq backup :53/udp, pf isolation |
| 4 | `<MAC4_IP>` | Backend B :3002, nginx standby edge :443, pf isolation, client |

## 2. Resilience tests and results

| # | Test | Expected | Observed (with times) | Result | Evidence |
|---|---|---|---|---|---|
| A1 | Both resolvers up; client lists both | Mac 1 answers | `<>` | `<PASS/FAIL>` | 09_DNS_both_up.png |
| A2 | Primary dnsmasq stopped | client resolves through Mac 3 | `<SERVER line, curl status>` | | 09_DNS_resolved_via_backup.png |
| B1 | TTL visible | `30 IN A` | `<>` | | 10_TTL_dig_ttl30.png |
| B2 | Record changed at `<time>` | client stale up to 30 s | `<stale from __ to __ = __ s>` | | 10_TTL_stale_after_change.png |
| B3 | Manual flush | immediate new answer | `<>` | | 10_TTL_flush_immediate.png |
| C1 | Client to backend port | timeout | `<>` | | 11_ISO_client_blocked.png |
| C2 | Edge to backend port | connects | `<>` | | 11_ISO_edge_allowed.png |
| C3 | Rollback | direct access restored | `<>` | | 11_ISO_rollback_restored.png |
| D1 | Backend A stopped at `<time>` | 100% served by B, 0 errors | `<N requests, N errors>` | | 12_HA_A_down_all_B.png |
| D2 | Backend A restarted at `<time>` | A/B resumes in ≤ 10 s | `<resumed after __ s>` | | 12_HA_A_back_resumes.png |
| E1 | `app` moved to standby at `<time>` | cached clients still on primary ≤ 30 s | `<primary until __, standby from __>` | | 13_EDGE_switched_standby.png |
| E2 | Fresh client after cutover | standby immediately | `<>` | | 13_EDGE_fresh_client_standby.png |
| F | Practice faults | correct layer found | see section 3 | | 14_TS_*.png |

## 3. Troubleshooting findings

| Fault (injected by) | First symptom | How we isolated it (commands, in order) | Layer | Fix | Time taken |
|---|---|---|---|---|---|
| `<>` | `<>` | `<dig, then nc, then openssl, then curl>` | `<>` | `<>` | `<>` |
| Faculty fault (demo day) | | | | | |

Problems we hit while building Phase 2 (honest list): `<for example, IPs changed through DHCP, brew PATH over SSH, mDNSResponder cache hid the failover until we flushed>`

## 4. Learning summary (one paragraph per extension)

**Ext A: Backup DNS.** `<Draft:>` DNS is an independent service whose failure looks completely different from an application failure. With both resolvers listed, the macOS resolver sent our query to Mac 1. When dnsmasq there was stopped, Mac 1 returned ICMP port-unreachable and the client retried on Mac 3, which answered from an identical copy of the zone. Name resolution survived, and the `query[A] ... from <client>` lines in the backup's log prove who answered. If DNS dies, clients cannot even find the edge ("Could not resolve host"). If the backends die, DNS and TLS still work and the edge returns 502. Redundant resolvers must hold identical data, or failover silently changes answers.

**Ext B: TTL.** `<Draft:>` The TTL is a promise from the server to every cache that the answer stays valid for N seconds. After we changed `app` the server answered with the new IP at once, but the client kept using the cached old IP until its 30 s timer expired. Our countdown probe showed the TTL dropping to 0 before the new IP appeared. Flushing the cache skipped the wait. In production this means lowering the TTL well before a migration, keeping the old endpoint alive for at least one TTL, and accepting that some clients cache longer than they should.

**Ext C: Service isolation.** `<Draft:>` Using pf rules in a dedicated anchor, each backend accepted TCP on its port only from Mac 2. Clients timed out (dropped SYN), while the edge, and therefore the service, kept working. This enforces "clients only ever talk to the edge" at the network layer instead of by convention, the same idea as a cloud security group that admits only the load balancer. Keeping the rules in a separate anchor with a saved copy of the original pf.conf made the rollback a single command.

**Ext D: HA failover.** `<Draft:>` nginx's passive health checks detected the stopped Backend A from the failed connect (RST), retried the same request on Backend B, and marked A down for 10 s. The client saw zero errors. When A returned, nginx probed it after `fail_timeout` and round-robin resumed. The remaining single point of failure is the edge itself (and the Wi-Fi LAN). Removing it needs a second edge plus a way to move clients: a floating VIP (VRRP) or health-checked DNS.

**Ext E: Edge migration.** `<Draft:>` We started an identical nginx on Mac 4 and moved `app` to it in both DNS servers. Because the certificate is bound to the name, not the IP, the standby served valid TLS without a new certificate. Clients with a cached answer kept reaching Mac 2 (`X-Edge: primary`) until their TTL expired, while new lookups went straight to the standby. We kept the old edge running until its traffic drained, which is how DNS-based cutovers are done without dropping users.

**Ext F: Troubleshooting.** `<Draft:>` Diagnosing bottom-up (name, IP, TCP port, TLS, HTTP, backend) turns a vague "site is down" into one specific layer within a minute. The key discriminators: resolve failure means DNS; timeout means a dropped packet (wrong IP, host down or firewall); refused means no listener; a certificate error means trust or name; 502 with a healthy `/edge-health` means the backend tier.
