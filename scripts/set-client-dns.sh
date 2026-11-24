#!/usr/bin/env bash
# Configure THIS client Mac's resolvers.
#   both    -> primary (Mac 1) + backup   (Ext A)
#   primary -> Mac 1 only                 (Phase 1 setup)
#   reset   -> back to DHCP default
#   flush   -> just flush the macOS DNS cache
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"
flush() { sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; echo "[$(date '+%T')] DNS cache flushed"; }
case "${1:-both}" in
  both)    sudo networksetup -setdnsservers "$WIFI_SERVICE" "$MAC1_IP" "$BACKUP_DNS_IP"; flush ;;
  primary) sudo networksetup -setdnsservers "$WIFI_SERVICE" "$MAC1_IP"; flush ;;
  reset)   sudo networksetup -setdnsservers "$WIFI_SERVICE" empty; flush ;;
  flush)   flush ;;
  *) echo "usage: set-client-dns.sh both|primary|reset|flush"; exit 1 ;;
esac
echo "networksetup: $(networksetup -getdnsservers "$WIFI_SERVICE" | tr '\n' ' ')"
scutil --dns | awk '/^resolver #1/{f=1} f&&/nameserver/{print "  scutil resolver#1 " $0} /^resolver #2/{exit}'
