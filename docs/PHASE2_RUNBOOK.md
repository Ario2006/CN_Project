# Phase 2 Runbook (Harden, Recover, Troubleshoot)

Every Phase 2 extension was run end-to-end on 24 Nov 2026, with output saved under `evidence/09_*` to `evidence/14_*`.
Demo order and speakers are in [EVAL_PLAN.md](EVAL_PLAN.md), live-change recipes in [COOKBOOK.md](COOKBOOK.md), Mac 4's commands in [ANKITA_MAC4.md](ANKITA_MAC4.md).

## Roles

| Mac | Person | Phase 1 | Phase 2 additions | How we operate it |
|---|---|---|---|---|
| 1 | Aryan | primary DNS (dnsmasq) + client | observer client for B/E | local |
| 2 | Ranajeet | primary edge nginx (TLS, LB) | passive health checks, `X-Edge`, `/edge-health` | `ssh mac2` |
| 3 | Abhijeet | Backend A :3001 | **backup DNS** (Ext A), **standby edge** (Ext E), pf (Ext C) | `ssh mac3` |
| 4 | Ankita | Backend B :3002 + client | pf (Ext C) | Ankita types the commands herself (no SSH) |

## Script map (all print the real command before running it)

| Purpose | Script |
|---|---|
| Health of the whole system | `scripts/preflight.sh` |
| Reset to the known-good state | `scripts/reset-baseline.sh` (this Mac) / `scripts/reset-baseline.sh all` (from Mac 1) |
| IPs changed | `scripts/set-ip.sh auto <mac4-ip>`, then `scripts/sync.sh` |
| Services | `scripts/dns-ctl.sh primary\|backup …`, `scripts/edge-ctl.sh primary\|standby …`, `scripts/backend-ctl.sh A\|B …` |
| Client DNS | `scripts/set-client-dns.sh both\|primary\|flush\|reset` |
| Move `app` | `scripts/dns-set-app.sh primary\|standby\|mac3\|<ip>` (run on Mac 1 **and** Mac 3) |
| Isolation | `scripts/firewall.sh apply\|status\|rollback` (on Mac 3 / Mac 4) |
| Observe | `scripts/watch-requests.sh N 1`, `scripts/ttl-watch.sh app.teamTeamCN.test N`, `scripts/ttl-cache-probe.sh`, `scripts/dns-failover-check.sh --flush` |
| Diagnose | `scripts/diagnose.sh` (client), `scripts/diagnose-edge.sh` (on the edge) |
| Evidence | `scripts/evidence.sh <file.txt> <cmd…>` (text), `scripts/capture.sh <preset> <file.pcap> [s]` (packets), `scripts/save-shot.sh` (screenshot) |
| Fault drills | `scripts/fault.sh list\|inject N\|undo N` |
| Demo, one script per section 8 step | `demo/00-preflight.sh` … `demo/10-diagnose.sh` |

Over SSH, our scripts run with a scoped passwordless sudo rule (`scripts/sudo-setup.sh`). It's limited to nginx, dnsmasq, pfctl, tcpdump, networksetup, dscacheutil, killall, pkill and lsof. Remove it after the evaluation.

## Extension by extension: what we ran and what we saw

### Ext A: Backup DNS (`demo/09a-backup-dns.sh`)
- Mac 3 runs `dns/team-dnsmasq-backup.conf`, which holds records identical to the primary's (the demo `diff`s them). Clients list `Mac1 Mac3`.
- Primary stopped at 23:26:11. `dig` showed `SERVER: <Mac3>#53`, the system resolver still returned the edge, curl gave 200.
- Evidence: `evidence/09_BACKUP_DNS/09_DNS_failover_demo.txt`.

### Ext B: TTL and record change (`demo/09b-ttl.sh`)
- `dig` shows `30 IN A`. `app` was moved to Mac 3 at 23:28:10. The client stayed **STALE** (cached old IP) until 23:28:45 and was in sync at 23:28:47. Changing back plus a **flush** took effect immediately.
- Evidence: `evidence/10_TTL/10_TTL_demo.txt`. Extra visual: `scripts/ttl-cache-probe.sh` shows the TTL counting down.

### Ext C: Service isolation (`demo/09c-isolation.sh`)
- pf rules live in the anchor `com.apple/250.CNIsolation` (`/etc/pf.conf` is untouched), from `firewall/backend-{A,B}.pf`: pass from Mac 2, `block drop` for everyone else.
- Result (23:48, both backends): Mac 1 timed out on 3001 and 3002, Mac 2 connected to both, the service through the edge stayed 200 A/B, and pf states showed only Mac 2. Rollback restored direct access. Evidence: `evidence/11_ISOLATION/`.
- Rollback copy: `firewall/backup/<host>-<time>/` (pf.conf.original, rules and status from before).
- Mac 4 needs Ankita: `scripts/firewall.sh apply` / `rollback`.

### Ext D: HA failover (`demo/08-backend-fail.sh`)
- Backend A stopped at 23:24:38. Every request returned 200 from B. The nginx log showed `upstream=A:3001, B:3002 upstream_status=504, 200` plus `upstream server temporarily disabled`.
- A restarted at 23:24:51 and rejoined at 23:25:10 (after `fail_timeout=10s` and its startup time).
- SPOF: the active edge (and the LAN). Evidence: `evidence/12_HA_FAILOVER/12_HA_failover_demo.txt`.

### Ext E: Edge cutover (`demo/09e-edge-cutover.sh`)
- Standby nginx on Mac 3 (`nginx/nginx-standby.conf`) differs from the primary only in the `X-Edge` name. It uses the same cert, because the cert names the domain, not an IP.
- `app` cut over to Mac 3 on both DNS servers at 23:30:38. The cached client stayed on `X-Edge: primary` until 23:31:09, then `standby` from 23:31:10. **0 failed requests out of 43.**
- Evidence: `evidence/13_EDGE_CUTOVER/13_EDGE_cutover_demo.txt`.

### Ext F: Troubleshooting (`demo/10-diagnose.sh`)
Drilled faults (`scripts/fault.sh`), each diagnosed by `scripts/diagnose.sh`:

| Fault | Diagnosis verdict |
|---|---|
| 1 client DNS = 8.8.8.8 | DNS: client not using team DNS |
| 2 record → 10.7.0.250 | timeout at L3/L4, **ROOT CAUSE: DNS data** (wrong entry) |
| 3 both DNS servers stopped | DNS: no server answers |
| 4 nginx stopped | L4: connection refused |
| 5 nginx on 8443 | L4: refused on 443 |
| 7 upstream port typo | **DEGRADED: only B answers** (failover hides it); `diagnose-edge.sh` shows `:3011 refused` |
| 10 pf on A blocks the edge | **DEGRADED: only B answers** |

Evidence: `evidence/14_TROUBLESHOOT/14_TS_fault*.txt`.

## Packet captures (you run these; tcpdump writes into evidence/)
```bash
# Ext A on Mac 1: query to Mac 1 (no answer or ICMP unreachable) -> query to Mac 3
scripts/capture.sh dnsfail evidence/09_BACKUP_DNS/09_DNS_failover.pcap 15 &
sleep 2; scripts/dns-ctl.sh primary stop; scripts/set-client-dns.sh flush; dig app.teamTeamCN.test; wait; scripts/dns-ctl.sh primary start

# Ext D on Mac 2 (ssh mac2): SYNs to :3001 unanswered -> same request to :3002
scripts/capture.sh backend evidence/12_HA_FAILOVER/12_HA_retry.pcap 20
#   ...meanwhile on Mac 1: ssh mac3 'cd ~/CN_Project && scripts/backend-ctl.sh A stop'; scripts/watch-requests.sh 5 1; ssh mac3 'cd ~/CN_Project && scripts/backend-ctl.sh A start'

# Ext E on Mac 1: TLS handshake moves from Mac 2's IP to Mac 3's IP after the TTL
scripts/capture.sh https evidence/13_EDGE_CUTOVER/13_EDGE_cutover.pcap 60 &   # then run demo/09e-edge-cutover.sh
```
Open with `open -a Wireshark <file>`.

## Final rollback (after the evaluation)
```bash
scripts/reset-baseline.sh all                 # services back to the Phase 2 baseline
ssh mac3 'cd ~/CN_Project && scripts/edge-ctl.sh standby stop; rm /opt/homebrew/etc/nginx/certs/edge-key.pem'
bash scripts/sudo-setup.sh remove              # and over ssh -t on mac2 / mac3
scripts/set-client-dns.sh reset                # only when the project is completely over
```
