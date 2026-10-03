# Phase 1 demo script, checklists, one-pagers

## Demo script (faculty order)
Standing setup: Ankita's Mac = client (terminal + browser + Wireshark with saved pcap). Mac 1 dnsmasq log visible, Mac 2 `tail -f /tmp/nginx-cn-access.log`, Mac 3/4 backend terminals. Repo open in editor.

| # | Step | Run / show | Say | Likely question -> ideal answer |
|---|---|---|---|---|
| 1 | Topology + inventory | docs/topology.png, docs/ip-service-inventory.md | Four roles on one /19 Wi-Fi; client knows only a name | Why is Mac 2 the only entry point? -> One public face: TLS, balancing, hiding/replacing backends without client change |
| 2 | LAN | `scripts/verify-lan.sh` on 2 Macs | Same subnet 10.7.0.0/19, same gateway; ping = L3 reachability | Why same subnet? -> (IP AND mask) equal => direct L2 delivery, no router. Does ping prove the app works? -> No, only IP/ICMP |
| 3 | DNS | `dig app.teamX.test` | Server 10.7.30.82 answered with Mac 2's IP; DNS only finds the IP | Does DNS connect you? -> No; TCP/TLS/HTTP are separate steps. Why .test? -> reserved; .local clashes with mDNS |
| 4 | HTTPS by name | `/usr/bin/curl -v https://app.teamX.test/api/status` + browser | Verified by a CA in the keychain, SAN matches, no -k | What is SAN? -> names the cert is valid for; clients ignore CN. Why trusted? -> signed by a CA our OS trusts |
| 5 | Load balancing | `scripts/verify-edge.sh` | nginx round-robins A,B,A,B; client never sees backend IPs | Why A then B? -> default round-robin in the upstream block. Cloud equivalent? -> ALB target group |
| 6 | Wireshark | saved pcap: dns, SYN, tls.handshake, Application Data | UDP 53 -> TCP 3-way -> TLS 1.2 -> encrypted app data; client ephemeral port -> 53/443 | What are seq/ack? -> byte counters giving reliability, ordering, retransmission; SYN consumes 1 sequence number. Why encrypted? -> TLS record layer after Finished |
| 7 | Caching | `curl -sI .../api/cache`, conditional curl | max-age=60 fresh; ETag revalidation -> 304 with no body | Fresh hit vs conditional vs new? -> fresh: no network; conditional: network round trip, tiny 304; new: full 200 |
| 8 | Stop one backend | Ctrl+C Backend A, loop curl | All answers from B; nginx log shows retry | What failed over? -> proxy_next_upstream after connect error; max_fails/fail_timeout marks A down 5 s |
| 9 | Failure scenarios | Phase 9 of the runbook, in order | Each isolates one layer | See the failure table in the runbook |
| 10 | Explain flow | one-minute flow below | | |
| 11 | Individual viva | any member, any component | | |

## One-minute request flow
"The client types https://app.teamX.test. The OS resolver sends a UDP query on port 53 to our dnsmasq on Mac 1, which answers with Mac 2's IP; DNS only gives an address. The client then opens a TCP connection to Mac 2 port 443: SYN, SYN-ACK, ACK, with sequence numbers that give reliable, ordered delivery. On top of TCP, TLS starts: ClientHello with SNI, ServerHello, certificate with SAN, key exchange, ChangeCipherSpec and Finished. The certificate chains to our local CA that every Mac trusts, so there is no warning. Now HTTP is sent encrypted. nginx terminates TLS, picks the next backend in the round-robin pool, opens a plain HTTP connection to Mac 3 port 3001 or Mac 4 port 3002, and relays the JSON and the X-Backend header back. Cache-Control and ETag let the client reuse or revalidate the response. The client never learns a backend IP."

## One-page architecture explanation
Four Macs on one private Wi-Fi subnet (10.7.0.0/19). Mac 1: DNS authority for teamX.test (Route 53 analogue). Mac 2: the only entry point; terminates TLS, balances round-robin over two backends, fails over passively (ALB analogue). Mac 3/4: identical stateless REST services on 3001/3002 returning JSON plus X-Backend, with one cacheable endpoint using ETag. Name -> IP (DNS, UDP 53) -> reliable pipe (TCP) -> confidentiality + server identity (TLS) -> semantics (HTTP). Each layer fails differently, so faults are diagnosed bottom-up: LAN, IP, DNS, TCP, TLS, HTTP, backend.

## Checklists (tick only with real evidence)
**Completion**
- [ ] 4 Macs same LAN; IP/mask/GW/iface/MAC recorded for all
- [ ] Ping OK between all pairs
- [ ] dnsmasq on Mac 1; >= 2 other Macs use it; dig/nslookup -> Mac 2 IP; no /etc/hosts
- [ ] Backends on 3001/3002 bound to the LAN; / and /api/status return JSON + X-Backend
- [ ] nginx upstream pool; A/B alternate by name
- [ ] HTTPS trusted on every Mac, SAN correct, no -k
- [ ] Cache-Control + ETag + 304 shown
- [ ] Wireshark: DNS, TCP handshake, TLS handshake, encrypted data, ports
- [ ] 5 failure demos done and explained

**Missing items (fill in during the day):** ________________

**Evidence:** every row of docs/evidence-matrix.md has a real file committed.

**Demo:** all 4 terminals running; pcap saved and opens; topology.png ready; resolver set on clients; browser shows padlock.

**Viva:** each member has answered at least 10 questions outside their own role.

**Rollback / disaster recovery**
- Client DNS: `sudo networksetup -setdnsservers Wi-Fi empty`, then `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
- Mac 1: Ctrl+C dnsmasq (no service was installed)
- Mac 2: `sudo "$(brew --prefix)/bin/nginx" -c "$PWD/nginx/nginx.conf" -s stop`
- Trust: `sudo security remove-trusted-cert -d tls/rootCA.pem`; on Mac 2 also `mkcert -uninstall`
- Backends: Ctrl+C
- IP changed: Aryan edits env.sh -> render-configs.sh -> push; everyone pulls; restart dnsmasq/nginx; re-point clients' DNS
