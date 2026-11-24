#!/usr/bin/env bash
# Update IPs in env.sh.
#   scripts/set-ip.sh auto <mac4-ip>     (Mac 1: reads own IP + Mac 2/3 over SSH; Ankita tells you hers)
#   scripts/set-ip.sh mac2 10.7.26.115   (set one)
# then: scripts/sync.sh "new IPs"
source "$(dirname "$0")/lib.sh"
setip() { sed -i '' "s/^export ${1}_IP=\"[0-9.]*\"/export ${1}_IP=\"$2\"/" "$ROOT/env.sh"; echo "$1 -> $2"; }
if [ "${1:-}" = auto ]; then
  setip MAC1 "$(myip)"
  for m in 2 3; do ip="$(ssh -o BatchMode=yes -o ConnectTimeout=4 mac$m 'ipconfig getifaddr en0')" && setip "MAC$m" "$ip"; done
  [ -n "${2:-}" ] && setip MAC4 "$2" || warn "Mac 4 not updated: pass Ankita's IP (she runs: ipconfig getifaddr en0)"
else
  M="$(echo "${1:?usage: set-ip.sh auto <mac4-ip> | macN <ip>}" | tr '[:lower:]' '[:upper:]')"; setip "$M" "${2:?ip}"
fi
grep -E '^export MAC[1-4]_IP' "$ROOT/env.sh"
