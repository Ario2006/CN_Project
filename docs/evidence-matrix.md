# Evidence matrix (Phase 1)
Every file lives under `evidence/<folder>/`. Take each one for real; never mock.

> **Audit Status:** All evidence items audited and verified — **100% Present** (all files committed under `evidence/`).

| # | Status | Requirement | Command / test | Expected | Filename | Viva explanation | Who |
|---|---|---|---|---|---|---|---|
| 1 | [x] Present | IPs, mask, GW, iface, MAC (A) | `scripts/verify-lan.sh` on each Mac | role, IP, /19, 10.7.0.1, en0, MACs | 01_LAN/01_LAN_IP_inventory_NAME.png | subnet, gateway, on-air vs hardware MAC | all |
| 2 | [x] Present | Pairwise ping (A) | same script, ping matrix | OK for all 3 peers | 01_LAN/01_LAN_ping_matrix_NAME.png | ICMP proves L3 reachability only | all |
| 3 | [x] Present | Topology (A) | GitHub render of docs/architecture.md | diagram | docs/topology.png + 01_LAN/01_LAN_topology.png | roles, cloud equivalents | Aryan |
| 4 | [x] Present | dnsmasq config (B) | `cat dns/team-dnsmasq.conf` | host-records -> Mac 2 | 02_DNS/02_DNS_dnsmasq_conf.png | host-record, local=, no-hosts | Aryan |
| 5 | [x] Present | Client resolver = Mac 1 (B) | `scutil --dns \| grep -m2 nameserver`; `networksetup -getdnsservers Wi-Fi` | 10.7.30.82 | 02_DNS/02_DNS_resolver_config_NAME.png | who answers; not /etc/hosts | 3 clients |
| 6 | [x] Present | dig app (B) | `dig app.teamX.test` | ANSWER 10.7.7.179, SERVER 10.7.30.82 | 02_DNS/02_DNS_dig_app.png | DNS = find IP only | client |
| 7 | [x] Present | dig api / nslookup (B) | `dig api.teamX.test`; `nslookup app.teamX.test` | 10.7.7.179 | 02_DNS/02_DNS_api_record.png, 02_DNS_nslookup.png | | client |
| 8 | [x] Present | DNS server log | dnsmasq terminal | `query[A] app... from <client IP>` | 02_DNS/02_DNS_server_log.png | | Aryan |
| 9 | [x] Present | Backend A (C) | `curl -si http://10.7.2.73:3001/api/status` | 200 JSON, X-Backend: A | 03_BACKENDS/03_BACKEND_A_status.png | | Abhijeet |
| 10 | [x] Present | Backend B (C) | `curl -si http://10.7.5.46:3002/api/status` | 200 JSON, X-Backend: B | 03_BACKENDS/03_BACKEND_B_status.jpeg | | Ankita |
| 11 | [x] Present | LAN-bound listeners (C) | `lsof -nP -iTCP:3001 -sTCP:LISTEN` | `*:3001`, not 127.0.0.1 | 03_BACKENDS/03_BACKEND_A_listen.png, 03_BACKEND_B_listen.jpeg | bind address | both |
| 12 | [x] Present | Cross-Mac direct reach (C) | `scripts/verify-backends.sh` from Mac 1 | both OK | 03_BACKENDS/03_BACKENDS_direct_connectivity_A.png, _B.png | | Aryan |
| 13 | [x] Present | Upstream config (D) | `sed -n '/upstream/,/^    }/p' nginx/nginx.conf` | pool of 2 | 04_NGINX/04_NGINX_upstream_config.png | | Ranajeet |
| 14 | [x] Present | Round-robin (D) | `scripts/verify-edge.sh` | A,B,A,B... | 04_NGINX/04_NGINX_load_balance_A_B.png | client never sees backend IP | client |
| 15 | [x] Present | nginx access log (D) | `tail /tmp/nginx-cn-access.log` | upstream=...:3001 / :3002 | 04_NGINX/04_NGINX_access_log_upstreams.png | | Ranajeet |
| 16 | [x] Present | SAN (E) | `openssl x509 -in tls/edge.pem -noout -text \| grep -A1 Alternative` | DNS:app..., DNS:api... | 05_TLS/05_TLS_certificate_SAN.png | SAN not CN | Ranajeet |
| 17 | [x] Present | Trusted, no -k (E) | `/usr/bin/curl -v https://app.teamX.test/api/status` | verify ok, 200 | 05_TLS/05_TLS_curl_no_k.png | chain of trust | client |
| 18 | [x] Present | Browser padlock (E) | Safari -> https://app.teamX.test | no warning | 05_TLS/05_TLS_browser_trusted.png | | client |
| 19 | [x] Present | CA trusted on each Mac (E) | Keychain Access (System) screenshot of the mkcert root, "Always Trust" | present | 05_TLS/05_TLS_CA_trusted_NAME.png | | all |
| 20 | [x] Present | Cache-Control + ETag (F) | `curl -sI https://app.teamX.test/api/cache` | max-age=60, ETag | 06_CACHE/06_CACHE_cache_control.png | | client |
| 21 | [x] Present | 304 (F) | `curl -si -H 'If-None-Match: "phase1-cache-v1"' ...` | 304 | 06_CACHE/06_CACHE_304.png | fresh vs conditional vs new | client |
| 22 | [x] Present | Browser cache states (F) | DevTools Network: load, Cmd+R, Cmd+Shift+R | 200 / 304 / 200 | 06_CACHE/06_CACHE_browser_devtools.png | | client |
| 23 | [x] Present | DNS packets (G) | Wireshark `dns` | query + response 10.7.7.179, UDP 53, ephemeral src | 07_WIRESHARK/07_WIRESHARK_DNS.png | | client |
| 24 | [x] Present | TCP handshake (G) | `tcp.flags.syn==1 \|\| tcp.flags.fin==1` plus follow-up | SYN, SYN-ACK, ACK | 07_WIRESHARK/07_WIRESHARK_TCP_handshake.png | seq/ack | client |
| 25 | [x] Present | TLS 1.2 handshake (G) | `tls.handshake` | ClientHello..Finished | 07_WIRESHARK/07_WIRESHARK_TLS_handshake.png (+ _certificate.png) | | client |
| 26 | [x] Present | Encrypted data (G) | `tls.record.content_type==23` | Application Data | 07_WIRESHARK/07_WIRESHARK_encrypted_data.png | why unreadable | client |
| 27 | [x] Present | Edge->backend hop (G) | capture on Mac 2, `tcp.port==3001 \|\| tcp.port==3002` | plain HTTP + X-Backend | 07_WIRESHARK/07_WIRESHARK_backend_hop_3001_3002.png.png | TLS terminated at edge | Ranajeet |
| 28 | [x] Present | Saved pcaps | files | open in Wireshark | 07_WIRESHARK/*.pcap | | all |
| 29-33 | [x] Present | 5 failure demos | runbook Phase 9 | | 08_FAILURES/08_FAILURE_wrong_dns.png, _wrong_ip.png, _backend_down.png, _both_backends_down.png, _wrong_port.png | symptom/layer/why | client |

