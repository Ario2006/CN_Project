# ===== SINGLE SOURCE OF TRUTH =====
# Edit ONLY this file when an IP changes, then run: scripts/render-configs.sh
# Then commit + push. Everyone else: git pull.

export TEAM="TeamCN"                         # team domain: teamX.test
export DOMAIN="team${TEAM}.test"
export IFACE="en0"
export WIFI_SERVICE="Wi-Fi"

# ---- Network & Subnet Mask ----
export SUBNET="10.7.0.0/19"
export NETMASK="255.255.224.0"
export NETMASK_HEX="0xffffe000"
export GATEWAY="10.7.0.1"
export BROADCAST="10.7.31.255"

# ---- Real IP Addresses ----
export MAC1_IP="10.7.30.82"             # Aryan     - DNS (dnsmasq) + test client
export MAC2_IP="10.7.7.179"             # Ranajeet  - nginx edge / LB / TLS
export MAC3_IP="10.7.19.31"             # Abhijeet  - Backend A :3001
export MAC4_IP="10.7.17.143"            # Ankita    - Backend B :3002 + capture client

# ---- Real On-The-Air MACs (Wireshark / 802.11 frames) ----
# KEEP THESE AS-IS until separately re-measured.
export MAC1_AIR_MAC="de:ee:5b:31:fc:1a"
export MAC2_AIR_MAC="06:a4:46:65:eb:bd"
export MAC3_AIR_MAC="8e:c9:23:39:6e:c1"
export MAC4_AIR_MAC="da:8e:64:df:05:3f"

# ---- Real Hardware MACs (networksetup permanent MACs) ----
export MAC1_HW_MAC="10:9f:41:be:57:6d"
export MAC2_HW_MAC="10:9f:41:bb:a2:9f"
export MAC3_HW_MAC="10:9f:41:c0:b2:b1"
export MAC4_HW_MAC="10:9f:41:c6:2a:38"

# ---- Ports ----
export BACKEND_A_PORT="3001"
export BACKEND_B_PORT="3002"
export HTTPS_PORT="443"

# ---- Upstream Resolvers ----
export UPSTREAM_DNS_1="10.5.7.1"         # campus resolver
export UPSTREAM_DNS_2=""                 # no public fallback