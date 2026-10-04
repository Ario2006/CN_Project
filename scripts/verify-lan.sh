#!/usr/bin/env bash
# Task A evidence: this Mac's L2/L3 facts + ping matrix + IP/MAC verification
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh"

IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null)"
MASK_HEX="$(ifconfig "$IFACE" 2>/dev/null | awk '/inet /{print $4}')"
BCAST="$(ifconfig "$IFACE" 2>/dev/null | awk '/inet /{print $6}')"
ONAIR_MAC="$(ifconfig "$IFACE" 2>/dev/null | awk '/ether/{print $2}')"
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
EXP_AIR_MAC=""
EXP_HW_MAC=""

if [ "$IP" = "$MAC1_IP" ]; then
  ROLE="Mac 1 (DNS)"
  EXP_AIR_MAC="$MAC1_AIR_MAC"
  EXP_HW_MAC="$MAC1_HW_MAC"
elif [ "$IP" = "$MAC2_IP" ]; then
  ROLE="Mac 2 (nginx edge)"
  EXP_AIR_MAC="$MAC2_AIR_MAC"
  EXP_HW_MAC="$MAC2_HW_MAC"
elif [ "$IP" = "$MAC3_IP" ]; then
  ROLE="Mac 3 (Backend A)"
  EXP_AIR_MAC="$MAC3_AIR_MAC"
  EXP_HW_MAC="$MAC3_HW_MAC"
elif [ "$IP" = "$MAC4_IP" ]; then
  ROLE="Mac 4 (Backend B)"
  EXP_AIR_MAC="$MAC4_AIR_MAC"
  EXP_HW_MAC="$MAC4_HW_MAC"
fi

echo "================ THIS MAC ($(hostname -s), $(date '+%F %T')) ================"
echo "Role in env.sh     : $ROLE"
echo "Interface          : $IFACE"
echo "IPv4               : $IP"
echo "Netmask            : $DOTTED ($MASK_HEX) => /$bits (expected: $NETMASK / $SUBNET)"
echo "Broadcast          : $BCAST (expected: $BROADCAST)"
echo "Default gateway    : $GW (expected: $GATEWAY)"
echo "MAC (on the air)   : $ONAIR_MAC (expected: ${EXP_AIR_MAC:-N/A})"
echo "MAC (hardware)     : $HW_MAC (expected: ${EXP_HW_MAC:-N/A})"
echo

echo "================ PING MATRIX (from this Mac) ================"
for entry in "Mac1-DNS:$MAC1_IP:$MAC1_AIR_MAC" "Mac2-nginx:$MAC2_IP:$MAC2_AIR_MAC" "Mac3-BackendA:$MAC3_IP:$MAC3_AIR_MAC" "Mac4-BackendB:$MAC4_IP:$MAC4_AIR_MAC"; do
  IFS=: read -r name ip air_mac <<<"$entry"
  if [ "$ip" = "$IP" ]; then printf '%-15s %-15s (this Mac)       MAC: %s\n' "$name" "$ip" "$air_mac"; continue; fi
  if out="$(ping -c 3 -t 5 -q "$ip" 2>&1)"; then
    rtt="$(echo "$out" | awk -F'/' '/round-trip/{print $5}')"
    printf '%-15s %-15s OK   avg %8s ms  MAC: %s\n' "$name" "$ip" "$rtt" "$air_mac"
  else
    printf '%-15s %-15s FAIL                  MAC: %s\n' "$name" "$ip" "$air_mac"
  fi
done
