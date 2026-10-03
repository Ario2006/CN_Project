#!/usr/bin/env bash
# Task A evidence: this Mac's L2/L3 facts + ping matrix + IP drift check
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"

IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
MASK_HEX="$(ifconfig "$IFACE" | awk '/inet /{print $4}')"
BCAST="$(ifconfig "$IFACE" | awk '/inet /{print $6}')"
ONAIR_MAC="$(ifconfig "$IFACE" | awk '/ether/{print $2}')"
HW_MAC="$(networksetup -getmacaddress "$WIFI_SERVICE" 2>/dev/null | awk '{print $3}')"
GW="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')"
h="${MASK_HEX#0x}"
DOTTED="$((16#${h:0:2})).$((16#${h:2:2})).$((16#${h:4:2})).$((16#${h:6:2}))"
bits=0
for i in 0 1 2 3 4 5 6 7; do
  d=$((16#${h:i:1}))
  while [ "$d" -gt 0 ]; do bits=$((bits + (d & 1))); d=$((d >> 1)); done
done

ROLE="UNKNOWN -> your IP is not in env.sh! Tell Aryan (IP changed?)"
[ "$IP" = "$MAC1_IP" ] && ROLE="Mac 1 (DNS)"
[ "$IP" = "$MAC2_IP" ] && ROLE="Mac 2 (nginx edge)"
[ "$IP" = "$MAC3_IP" ] && ROLE="Mac 3 (Backend A)"
[ "$IP" = "$MAC4_IP" ] && ROLE="Mac 4 (Backend B)"

echo "================ THIS MAC ($(hostname -s), $(date '+%F %T')) ================"
echo "Role in env.sh     : $ROLE"
echo "Interface          : $IFACE"
echo "IPv4               : $IP"
echo "Netmask            : $DOTTED ($MASK_HEX)  =>  /$bits"
echo "Broadcast          : $BCAST"
echo "Default gateway    : $GW"
echo "MAC (on the air)   : $ONAIR_MAC   <- what Wireshark will show"
echo "MAC (hardware)     : $HW_MAC"
echo
echo "================ PING MATRIX (from this Mac) ================"
for entry in "Mac1-DNS:$MAC1_IP" "Mac2-nginx:$MAC2_IP" "Mac3-BackendA:$MAC3_IP" "Mac4-BackendB:$MAC4_IP"; do
  name="${entry%%:*}"; ip="${entry##*:}"
  if [ "$ip" = "$IP" ]; then printf '%-15s %-15s (this Mac)\n' "$name" "$ip"; continue; fi
  if out="$(ping -c 3 -t 5 -q "$ip" 2>&1)"; then
    rtt="$(echo "$out" | awk -F'/' '/round-trip/{print $5}')"
    printf '%-15s %-15s OK    avg %s ms\n' "$name" "$ip" "$rtt"
  else
    printf '%-15s %-15s FAIL\n' "$name" "$ip"
  fi
done
