# ===== SINGLE SOURCE OF TRUTH =====
# Edit ONLY this file when an IP changes, then run: scripts/render-configs.sh
# Then commit + push. Everyone else: git pull.
export TEAM="X"                     # change to your real team number ONLY BEFORE generating the TLS cert
export DOMAIN="team${TEAM}.test"
export IFACE="en0"
export WIFI_SERVICE="Wi-Fi"         # check: networksetup -listallnetworkservices

export MAC1_IP="10.7.30.82"         # Aryan     - DNS (dnsmasq) + test client
export MAC2_IP="10.7.7.179"         # Ranajeet  - nginx edge / LB / TLS
export MAC3_IP="10.7.2.73"          # Abhijeet  - Backend A :3001
export MAC4_IP="10.7.5.46"          # Ankita    - Backend B :3002 + main capture client

export BACKEND_A_PORT="3001"
export BACKEND_B_PORT="3002"
export HTTPS_PORT="443"             # use 8443 only if 443 fails

export UPSTREAM_DNS_1="10.5.7.1"    # campus resolver (so Mac1 can still forward normal names)
export UPSTREAM_DNS_2="8.8.8.8"
