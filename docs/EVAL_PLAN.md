# Evaluation-day plan

Everything below was rehearsed live on 24 Nov 2026 (evidence in `evidence/09_*` to `evidence/14_*`).
Every demo script **prints the real command before running it**, so the examiner sees `dig`, `curl`, `nc`, `pfctl` and `nginx` being used, not magic.

## A. Arrive early: 15-minute bring-up

| # | Who / where | Command | Pass when |
|---|---|---|---|
| 1 | Everyone | Same Wi-Fi, chargers in, `caffeinate -dis &` | |
| 2 | Each person | `ipconfig getifaddr en0`, then tell Aryan | |
| 3 | Aryan (Mac 1) | `scripts/set-ip.sh auto <Ankita-IP>` | the 4 IPs are printed |
| 4 | Aryan | `scripts/sync.sh "eval-day IPs"` | Mac 2/3 pulled. **Ankita: `git pull`** |
| 5 | Aryan | `scripts/reset-baseline.sh all` (Ankita runs `scripts/reset-baseline.sh` when prompted) | each Mac says `at baseline` |
| 6 | Aryan | `ssh mac3 'cd ~/CN_Project && scripts/edge-ctl.sh standby start && scripts/edge-ctl.sh standby stop'` | warms Mac 3's firewall for nginx (avoids the first-connection timeout) |
| 7 | Aryan | `scripts/preflight.sh` | **ALL GREEN** |

If IPs changed after step 5: run `scripts/set-ip.sh`, then `scripts/sync.sh`, then restart DNS (`scripts/dns-ctl.sh primary restart`, and `ssh mac3 '...dns-ctl.sh backup restart'`), then `ssh mac2 '... edge-ctl.sh primary reload'`.

## B. Terminal layout on Mac 1
- **Tab 1, demo:** `cd CN_Project`, then run `demo/NN-*.sh` in order.
- **Tab 2, Mac 2 live log:** `ssh mac2`, `cd CN_Project`, `scripts/edge-ctl.sh primary log`.
- **Tab 3, Mac 1 DNS log:** `scripts/dns-ctl.sh primary log`.
- **Tab 4, Mac 3:** `ssh mac3`, `cd CN_Project`, `scripts/dns-ctl.sh backup log`.
- **Also open:** `docs/topology-phase2.png`, `docs/ip-service-inventory.md`, Wireshark with `evidence/07_WIRESHARK/client_full_tls12.pcap`.

> If the examiner wants each person to run their own Mac, set `DEMO_REMOTE=0`. The demo then prints "ON macN RUN: …" and waits, and the owner types it.

## C. The 11 steps of PDF section 8: script, speaker, key sentence

| # | Step | Run | Speaker | Key sentence |
|---|---|---|---|---|
| 1 | Topology + inventory | `demo/01-topology.sh` | Aryan | "Clients only know a name; DNS gives the edge; the edge hides two backends." |
| 2 | LAN | `demo/02-lan.sh` | Aryan | "Same subnet (IP AND mask), direct ARP delivery; ping proves L3 only." |
| 3 | DNS | `demo/03-dns.sh` | Aryan | "Our server answered (SERVER line), TTL 30; DNS finds the IP, it doesn't connect." |
| 4 | HTTPS by name | `demo/04-https.sh` | Ranajeet | "SAN matches, CA trusted, no -k; TLS terminates at Mac 2." |
| 5 | Load balancing | `demo/05-loadbalance.sh` | Ranajeet | "Round-robin A/B; the access log shows the upstream IP:port." |
| 6 | Wireshark | `demo/06-wireshark.sh` | Ranajeet | filters `dns`, `tcp.flags.syn==1`, `tls.handshake`, `tls.record.content_type==23` |
| 7 | Caching | `demo/07-cache.sh` | Abhijeet | "Fresh hit = no request; conditional = 304; new = 200." |
| 8 | Backend failure | `demo/08-backend-fail.sh` | Abhijeet | "504 to A then 200 from B in one request, A disabled 10 s, then it comes back." |
| 9a | Backup DNS (Ext A) | `demo/09a-backup-dns.sh` | Aryan | "SERVER switched to Mac 3; DNS failure vs app failure." |
| 9b | TTL (Ext B) | `demo/09b-ttl.sh` | Aryan | "STALE for one TTL, then the new IP; a flush skips the wait." |
| 9c | Isolation (Ext C) | `demo/09c-isolation.sh` (**Ankita applies/rolls back**) | Abhijeet + Ankita | "Client times out, the edge connects, the service still works; rollback restores it." |
| 9e | Edge cutover (Ext E) | `demo/09e-edge-cutover.sh` | Ankita | "Cached client stays on the primary until the TTL expires, then the standby; zero failures, same cert." |
| 10 | Faculty fault | `demo/10-diagnose.sh`, then fix | whoever is asked | say the method out loud (section D) |
| 11 | Viva | `docs/PHASE2_VIVA.md` | everyone | |

Between steps, if anything looks odd, run `scripts/preflight.sh`, then `scripts/reset-baseline.sh all`.

## D. The faculty fault (10 marks, method counts even if the fix is incomplete)
Say this out loud, then run `demo/10-diagnose.sh`:
1. "First, does the **name resolve**, via which server, to which IP?" (`dig`, `scutil --dns`, `/etc/hosts`)
2. "Can I **reach that IP**?" (`ping`, `arp`)
3. "Does **TCP connect** to 443?" Succeeded, refused (RST: nothing listening) or timeout (dropped: host off, wrong IP, firewall)? (`nc -vz`)
4. "Does **TLS** validate?" SAN, trust, expiry. (`openssl s_client`, `curl -v`)
5. "What **HTTP status** and which backend?" 502/504 means the problem is behind the edge, and `/edge-health` 200 proves the edge itself is fine. (`curl -v`)
6. "Are **both backends** serving?" If only one, it's degraded: failover is hiding a fault. (`diagnose-edge.sh` on Mac 2)

Typical fixes: `scripts/dns-set-app.sh primary`, `scripts/set-client-dns.sh both`, `scripts/edge-ctl.sh primary start|reload`, `scripts/backend-ctl.sh A start`, `scripts/firewall.sh rollback`, `scripts/render-configs.sh && edge-ctl.sh primary reload` (bad config), `scripts/reset-baseline.sh all`.

Practice with `scripts/fault.sh list`, `scripts/fault.sh inject N` and `scripts/fault.sh undo N`. All of them were rehearsed: see `evidence/14_TROUBLESHOOT/`.

## E. Known gotchas (learned while rehearsing)
- **Never add 8.8.8.8 to a client's DNS list.** It answers NXDOMAIN for `.test`, and macOS caches that, so our names break. Preflight flags it. Fix: `scripts/set-client-dns.sh both`.
- **Mac 3's macOS firewall** drops SYNs to closed ports, so a stopped Backend A shows up as **504 (connect timeout 1 s)**, not "refused". It's still failed over within the same request.
- **First connection to a new nginx binary on Mac 3** can time out while the macOS firewall registers it. Warm-up is bring-up step 6.
- **nginx keeps a failed backend disabled for 10 s** (`fail_timeout`). Right after you restore a backend, the first few requests may all go to the other one. Wait 10 s.
- **The client stays stale for about TTL + a few seconds** (we measured 30–37 s), because the cache timer started at the client's last lookup.
- **Campus resolver 10.5.7.1 may be down**, so upstream is 8.8.8.8 with campus as fallback (this only matters for internet names; our zone is local).
- The sudo rule for the project's tools stays until after the evaluation. Then run `bash scripts/sudo-setup.sh remove` on Macs 1–3.

## F. Deliverables checklist (PDF section 9)
- [x] Architecture document updated for Phase 2: `docs/architecture.md`, `docs/topology-phase2.png`
- [x] Config bundle: `dns/` (Phase 2 primary and backup, plus `dns/phase1/`), `nginx/` (Phase 2 primary and standby, plus `nginx/phase1/`), `firewall/` (rules plus rollback copy), `tls/certificate-setup.md`, `backend/`, `scripts/`
- [x] Evidence: `evidence/01–08` (Phase 1), `evidence/09–14` (Phase 2), indexed in `docs/evidence-matrix.md`
- [x] Phase 2 final report: `docs/PHASE2_REPORT.md`
- [ ] Screenshots of key moments, if you want them (text evidence is already saved): `scripts/save-shot.sh evidence/<folder>/<name>.png`
- [ ] Phase 2 pcaps (commands in `docs/PHASE2_RUNBOOK.md`, "Packet captures")
