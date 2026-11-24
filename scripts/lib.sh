# Shared helpers. Every script does:  source "$(dirname "$0")/lib.sh"   (or ../scripts/lib.sh)
# - loads env.sh (single source of truth)
# - run "<cmd>"  : PRINTS the exact command (so the examiner sees real dig/nc/curl/pfctl) then runs it
# - say "<txt>"  : the sentence to say out loud during the demo
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/env.sh"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:$PATH"   # brew tools over SSH

NGINX="$(command -v nginx || echo /opt/homebrew/bin/nginx)"
DNSMASQ="$(command -v dnsmasq || echo /opt/homebrew/sbin/dnsmasq)"
CURL=/usr/bin/curl                          # Apple curl: validates TLS against the System keychain
APP="app.${DOMAIN}"; API="api.${DOMAIN}"
PORTSUFFIX=""; [ "$HTTPS_PORT" != "443" ] && PORTSUFFIX=":$HTTPS_PORT"
URL="https://${APP}${PORTSUFFIX}"

if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'; else B= G= R= Y= C= N=; fi
say()  { printf '\n%s>> %s%s\n' "$C$B" "$*" "$N"; }
ok()   { printf '  %sOK%s    %s\n' "$G" "$N" "$*"; }
bad()  { printf '  %sFAIL%s  %s\n' "$R" "$N" "$*"; }
warn() { printf '  %sWARN%s  %s\n' "$Y" "$N" "$*"; }
hdr()  { printf '\n%s==== %s ====%s\n' "$B" "$*" "$N"; }
run()  { printf '%s$ %s%s\n' "$Y" "$*" "$N"; eval "$@"; }
pause(){ [ "${DEMO_NOPAUSE:-0}" = 1 ] && return; [ -t 0 ] || return; read -r -p "   [Enter to continue] " _; }

myip() { ipconfig getifaddr "$IFACE" 2>/dev/null; }
role() {   # what is THIS Mac in env.sh?
  case "$(myip)" in
    "$MAC1_IP") echo mac1 ;; "$MAC2_IP") echo mac2 ;; "$MAC3_IP") echo mac3 ;; "$MAC4_IP") echo mac4 ;; *) echo unknown ;;
  esac
}
label() {  # human label for an IP
  case "$1" in
    "$MAC1_IP") echo "Mac1-Aryan(DNS)";; "$MAC2_IP") echo "Mac2-Ranajeet(edge)";;
    "$MAC3_IP") echo "Mac3-Abhijeet(A+backupDNS+standby)";; "$MAC4_IP") echo "Mac4-Ankita(B+client)";; *) echo "unknown";;
  esac
}
need_role() {  # warn loudly if a script runs on the wrong Mac
  local want="$1"; [ "$(role)" = "$want" ] || warn "this Mac is $(myip) = $(role); this step is meant for $want (env.sh stale?)"
}

# on <mac1|mac2|mac3|mac4> "<command>"  - run a project command on another Mac.
#   This Mac             -> runs locally
#   DEMO_REMOTE=1 + SSH + passwordless sudo -> runs on mac2/mac3 over SSH (prints [mac2]$ cmd)
#   DEFAULT (DEMO_REMOTE=0): prints "ON macN RUN: <cmd>" and WAITS for Enter - the owner types it on their Mac
REMOTE_DIR="${REMOTE_DIR:-~/CN_Project}"
on() {
  local h="$1"; shift; local cmd="$*"
  if [ "$h" = "$(role)" ]; then run "$cmd"; return; fi
  if [ "${DEMO_REMOTE:-0}" = 1 ] && [ "$h" != mac4 ] && ssh -o BatchMode=yes -o ConnectTimeout=3 "$h" true 2>/dev/null; then
    printf '%s[%s]$ %s%s\n' "$Y" "$h" "$cmd" "$N"
    ssh -o BatchMode=yes "$h" "cd $REMOTE_DIR && $cmd"
  else
    local ip; ip="$(eval echo "\$$(echo "$h" | tr '[:lower:]' '[:upper:]')_IP")"
    printf '\n%s>>> ON %s (%s) RUN:%s  %s\n' "$B$Y" "$h" "$(label "$ip")" "$N" "$cmd"
    read -r -p "   [press Enter when done] " _ </dev/tty
  fi
}
