# IP / Service Inventory (Task A)

Network: campus Wi-Fi, subnet **10.7.0.0/19** (netmask **255.255.224.0**, hex **0xffffe000**, prefix **/19**), broadcast **10.7.31.255**, gateway **10.7.0.1**, interface **en0** on all Macs.

> All network parameters and MAC addresses audited and verified from physical LAN evidence (`evidence/01_LAN/`). Single source of truth = `env.sh`.

## Host Inventory (All 4 Macs)

| Mac | Person   | Hostname                | Role                       | IPv4       | Netmask / Prefix            | Broadcast   | Gateway  | Iface | MAC on the air (ifconfig) | MAC hardware (networksetup) |
| --- | -------- | ----------------------- | -------------------------- | ---------- | --------------------------- | ----------- | -------- | ----- | ------------------------- | --------------------------- |
| 1   | Aryan    | `MacBook-Pro-88`        | DNS (dnsmasq) + client     | 10.7.30.82 | 255.255.224.0 (`/19`)       | 10.7.31.255 | 10.7.0.1 | en0   | `de:ee:5b:31:fc:1a`       | `10:9f:41:be:57:6d`         |
| 2   | Ranajeet | `Ranajeets-MacBook-Pro` | nginx edge / LB / TLS      | 10.7.7.179 | 255.255.224.0 (`/19`)       | 10.7.31.255 | 10.7.0.1 | en0   | `06:a4:46:65:eb:bd`       | `10:9f:41:bb:a2:9f`         |
| 3   | Abhijeet | `Abhijeets-MacBook-Pro-3`| Backend A                 | 10.7.2.73  | 255.255.224.0 (`/19`)       | 10.7.31.255 | 10.7.0.1 | en0   | `8e:c9:23:39:6e:c1`       | `10:9f:41:c0:b2:b1`         |
| 4   | Ankita   | `Ankitas-MacBook-Pro`   | Backend B + capture client | 10.7.5.46  | 255.255.224.0 (`/19`)       | 10.7.31.255 | 10.7.0.1 | en0   | `da:8e:64:df:05:3f`       | `10:9f:41:c6:2a:38`         |

### Why two MAC addresses per Mac?
macOS "Private Wi-Fi Address" generates a per-network rotating MAC address on the air (`ifconfig en0 ether`). This is the layer-2 address present in all Wi-Fi 802.11 / Ethernet frames and Wireshark captures. The permanent factory MAC address is retrieved via `networksetup -getmacaddress Wi-Fi`.

---

## Service Port Mapping

| Service          | Host             | Port/Proto    | MAC on the air            | Reached by                        |
| ---------------- | ---------------- | ------------- | ------------------------- | --------------------------------- |
| dnsmasq (DNS)    | Mac 1 10.7.30.82 | 53/UDP (+TCP) | `de:ee:5b:31:fc:1a`       | all clients                       |
| nginx HTTPS edge | Mac 2 10.7.7.179 | 443/TCP       | `06:a4:46:65:eb:bd`       | clients, by name `app.teamX.test` |
| Backend A (REST) | Mac 3 10.7.2.73  | 3001/TCP      | `8e:c9:23:39:6e:c1`       | nginx only (normal flow)          |
| Backend B (REST) | Mac 4 10.7.5.46  | 3002/TCP      | `da:8e:64:df:05:3f`       | nginx only (normal flow)          |

---

## DNS Records (Local Zone: `teamX.test`)

| DNS name       | Type | Answer             | Host Role             | TTL  |
| -------------- | ---- | ------------------ | --------------------- | ---- |
| app.teamX.test | A    | 10.7.7.179 (Mac 2) | Edge (nginx TLS/LB)   | 30 s |
| api.teamX.test | A    | 10.7.7.179 (Mac 2) | Edge (nginx TLS/LB)   | 30 s |
