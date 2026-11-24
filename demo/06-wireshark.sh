#!/usr/bin/env bash
# Step 6: Wireshark evidence of DNS, TCP and TLS (saved pcap; optional live capture)
source "$(dirname "$0")/../scripts/lib.sh"
say "Saved capture of one full client request: DNS over UDP 53, TCP 3-way handshake to 443, TLS handshake, then encrypted Application Data."
P="$ROOT/evidence/07_WIRESHARK/client_full_tls12.pcap"
run "tcpdump -n -r '$P' 2>/dev/null | head -14"
cat <<'F'
Wireshark display filters to type, in order:
  dns                              -> query app... + answer (client ephemeral port -> 53)
  tcp.flags.syn==1                 -> SYN, SYN-ACK (then the ACK): ports + seq/ack numbers
  tls.handshake                    -> ClientHello (SNI), ServerHello, Certificate, Key Exchange, Finished
  tls.record.content_type==23      -> Application Data: encrypted, unreadable
F
run "open -a Wireshark '$P'"
pause
say "Optional LIVE capture (25 s): run a curl in another tab while this captures."
[ "${1:-}" = live ] && run "'$ROOT/scripts/capture.sh' https evidence/07_WIRESHARK/live_$(date +%H%M%S).pcap 25"
