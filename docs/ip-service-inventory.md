# IP / Service Inventory (Task A)

Network: campus Wi-Fi, subnet **10.7.0.0/19** (mask 255.255.224.0, hex 0xffffe000), gateway **10.7.0.1**, interface **en0** on all Macs.

> IPs are DHCP-assigned and may change. Single source of truth = `env.sh`. Re-run `scripts/verify-lan.sh` after moving.

| Mac | Person   | Role                       | IPv4       | Prefix       | Gateway  | Iface | MAC on the air (ifconfig) | MAC hardware (networksetup) |
| --- | -------- | -------------------------- | ---------- | ------------ | -------- | ----- | ------------------------- | --------------------------- |
| 1   | Aryan    | DNS (dnsmasq) + client     | 10.7.30.82 | /19          | 10.7.0.1 | en0   | de:ee:5b:31:fc:1a         | 10:9f:41:be:57:6d           |
| 2   | Ranajeet | nginx edge / LB / TLS      | 10.7.7.179 | /19 (verify) | 10.7.0.1 | en0   | 06:a4:46:65:eb:bd         | 10:9f:41:bb:a2:9f           |
| 3   | Abhijeet | Backend A                  | 10.7.2.73  | /19 (verify) | 10.7.0.1 | en0   | 8e:c9:23:39:6e:c1         | 10:9f:41:c0:b2:b1           |
| 4   | Ankita   | Backend B + capture client | 10.7.5.46  | /19 (verify) | 10.7.0.1 | en0   | da:8e:64:df:05:3f         | 10:9f:41:c6:2a:38           |

Why two MACs? macOS "Private Wi-Fi Address" uses a per-network random MAC on the air; Wireshark shows that one.

| Service          | Host             | Port/Proto    | Reached by                        |
| ---------------- | ---------------- | ------------- | --------------------------------- |
| dnsmasq (DNS)    | Mac 1 10.7.30.82 | 53/UDP (+TCP) | all clients                       |
| nginx HTTPS edge | Mac 2 10.7.7.179 | 443/TCP       | clients, by name `app.teamX.test` |
| Backend A (REST) | Mac 3 10.7.2.73  | 3001/TCP      | nginx only (normal flow)          |
| Backend B (REST) | Mac 4 10.7.5.46  | 3002/TCP      | nginx only (normal flow)          |

| DNS name       | Type | Answer             | TTL  |
| -------------- | ---- | ------------------ | ---- |
| app.teamX.test | A    | 10.7.7.179 (Mac 2) | 30 s |
| api.teamX.test | A    | 10.7.7.179 (Mac 2) | 30 s |
