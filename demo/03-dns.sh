#!/usr/bin/env bash
# Step 3: resolve the private name through OUR DNS server
source "$(dirname "$0")/../scripts/lib.sh"
say "The client asks our dnsmasq on Mac 1 over UDP 53; the answer is Mac 2's IP. DNS only finds the address - no connection yet."
run "networksetup -getdnsservers $WIFI_SERVICE"
run "dig $APP"; pause
run "dig +short $API"
run "nslookup $APP | tail -3"
