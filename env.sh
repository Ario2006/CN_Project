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
export MAC1_IP="10.7.20.4"              # Aryan     - DNS (dnsmasq) + test client
export MAC2_IP="10.7.26.115"            # Ranajeet  - nginx edge / LB / TLS
export MAC3_IP="10.7.18.174"            # Abhijeet  - Backend A :3001 + backup DNS + standby edge
export MAC4_IP="10.7.17.93"             # Ankita    - Backend B :3002 + test client

# ---- Real On-The-Air MACs (Wireshark / 802.11 frames) ----
# KEEP THESE AS-IS until separately re-measured.
export MAC1_AIR_MAC="d2:de:13:78:fa:39"
export MAC2_AIR_MAC="26:6d:dc:6e:22:ed"
export MAC3_AIR_MAC="8e:c9:23:39:6e:c1"
export MAC4_AIR_MAC="da:8e:64:df:05:3f"

# ---- Real Hardware MACs (networksetup permanent MACs) ----
export MAC1_HW_MAC="10:9f:41:be:57:6d"
export MAC2_HW_MAC="10:9f:41:bb:a2:9f"
export MAC3_HW_MAC="10:9f:41:c0:b2:b1"
export MAC4_HW_MAC="10:9f:41:c6:2a:38"

# ---- Ports ----
export BACKEND_A_PORT="${BACKEND_A_PORT:-3001}"
export BACKEND_B_PORT="${BACKEND_B_PORT:-3002}"
export HTTPS_PORT="${HTTPS_PORT:-443}"

# ---- Upstream Resolvers ----
export UPSTREAM_DNS_1="8.8.8.8"           # from DHCP (campus 10.5.7.1 unreachable on 24 Nov)
export UPSTREAM_DNS_2="10.5.7.1"          # campus resolver (fallback)

# ======================= PHASE 2 =======================
# Ext A - backup DNS resolver (must NOT be Mac 1). Default: Mac 3 (Abhijeet).
export BACKUP_DNS_IP="${MAC3_IP}"
export BACKUP_DNS_LABEL="Mac 3 (Abhijeet)"

# Ext E - standby edge nginx (same config as Mac 2). Mac 3 (Abhijeet): reachable over SSH.
export STANDBY_EDGE_IP="${MAC3_IP}"
export STANDBY_EDGE_LABEL="Mac 3 (Abhijeet)"

# Ext B/E - where app.$DOMAIN points. scripts/dns-set-app.sh overrides this per run.
# api.$DOMAIN always stays on the primary edge (Mac 2) as a control record.
export APP_RECORD_IP="${APP_RECORD_IP:-$MAC2_IP}"
export DNS_TTL="${DNS_TTL:-30}"                 # seconds; visible in dig ANSWER section

# Ext C - extra source IPs allowed to reach backend ports (space separated). Keep EMPTY
# for the demo (only Mac 2 may reach 3001/3002).
export FIREWALL_EXTRA_ALLOW="${FIREWALL_EXTRA_ALLOW:-}"

# Where brew's nginx finds the cert on EVERY edge machine (Apple Silicon default).
# Intel Mac edge? use /usr/local/etc/nginx/certs
export CERT_DIR="${CERT_DIR:-/opt/homebrew/etc/nginx/certs}"

# ---- Knobs the examiner may ask you to change (edit, then scripts/render-configs.sh + restart) ----
export LB_METHOD="${LB_METHOD:-round_robin}"   # round_robin | least_conn | ip_hash
export EXTRA_RECORDS="${EXTRA_RECORDS:-}"      # e.g. "db=10.7.18.174 www=10.7.26.115"  -> db.$DOMAIN etc.
