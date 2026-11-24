#!/usr/bin/env bash
# Step 2: all machines on the private LAN (IP, mask, gateway, MACs, ping matrix)
source "$(dirname "$0")/../scripts/lib.sh"
say "Same network = (IP AND mask) equal on every Mac, so frames go directly via ARP, no router. Ping proves L3 reachability only, not the app."
run "'$ROOT/scripts/verify-lan.sh'"
run "arp -an | grep -E '$MAC1_IP|$MAC2_IP|$MAC3_IP|$MAC4_IP' || true"
