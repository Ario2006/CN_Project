#!/usr/bin/env bash
# Packet capture with the right filter, saved straight into evidence/.
#   scripts/capture.sh <preset> <outfile.pcap> [seconds]      (default 25 s; Ctrl+C stops early)
# presets: dns | dnsfail | https | backend | all
#   dns     udp port 53                         (Phase 1 step 6 / Ext A/B)
#   dnsfail udp port 53 or icmp                 (Ext A: query -> ICMP port unreachable -> backup)
#   https   udp port 53 or tcp port 443         (DNS + TCP handshake + TLS handshake + encrypted data)
#   backend tcp port 3001 or tcp port 3002      (run on Mac 2: edge->backend hop, Ext D RST + retry, Ext C drops)
source "$(dirname "$0")/lib.sh"
P="${1:?usage: capture.sh dns|dnsfail|https|backend|all <outfile.pcap> [seconds]}"; OUT="${2:?outfile}"; SEC="${3:-25}"
case "$P" in
  dns) F="udp port 53";; dnsfail) F="udp port 53 or icmp";; https) F="udp port 53 or tcp port $HTTPS_PORT";;
  backend) F="tcp port $BACKEND_A_PORT or tcp port $BACKEND_B_PORT";; all) F="udp port 53 or icmp or tcp port $HTTPS_PORT or tcp port $BACKEND_A_PORT or tcp port $BACKEND_B_PORT";;
  *) F="$P";;
esac
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT";; esac; mkdir -p "$(dirname "$OUT")"
sudo -v || exit 1   # ask for the password NOW (tcpdump then runs in the background)
say "capturing '$F' on $IFACE for ${SEC}s -> ${OUT#$ROOT/}   (do the action NOW in another tab)"
printf '%s$ sudo tcpdump -i %s -n -w %s %s%s\n' "$Y" "$IFACE" "${OUT#$ROOT/}" "$F" "$N"
sudo tcpdump -i "$IFACE" -n -w "$OUT" $F &
stopcap() { sudo pkill -INT -f "tcpdump -i $IFACE -n -w" 2>/dev/null; }
trap 'stopcap' INT
sleep "$SEC"; stopcap; wait 2>/dev/null; trap - INT
echo; run "tcpdump -n -r '$OUT' 2>/dev/null | head -25"
echo "Open in Wireshark:  open -a Wireshark '$OUT'"
