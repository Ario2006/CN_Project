#!/usr/bin/env bash
# Put THIS Mac back into the known-good evaluation state (idempotent; safe to run any time).
#   scripts/reset-baseline.sh            (detects its own role)
#   scripts/reset-baseline.sh all        (from Mac 1: does Mac 1 + Mac 2 + Mac 3 over SSH, prints Mac 4's)
source "$(dirname "$0")/lib.sh"
if [ "${1:-}" = all ]; then
  for h in mac2 mac3; do on "$h" "scripts/reset-baseline.sh"; done
  on mac4 "scripts/reset-baseline.sh"
  "$0"; exit
fi
hdr "reset-baseline on $(role) ($(myip))"
case "$(role)" in
  mac1) "$ROOT/scripts/dns-ctl.sh" primary start >/dev/null
        [ "$(dig +short @"$MAC1_IP" "$APP")" = "$MAC2_IP" ] || "$ROOT/scripts/dns-set-app.sh" primary
        "$ROOT/scripts/set-client-dns.sh" both ;;
  mac2) "$ROOT/scripts/edge-ctl.sh" primary start ;;
  mac3) "$ROOT/scripts/firewall.sh" rollback >/dev/null 2>&1
        "$ROOT/scripts/edge-ctl.sh" standby stop >/dev/null 2>&1
        "$ROOT/scripts/backend-ctl.sh" A start
        "$ROOT/scripts/dns-ctl.sh" backup start >/dev/null
        [ "$(dig +short @"$MAC3_IP" "$APP")" = "$MAC2_IP" ] || "$ROOT/scripts/dns-set-app.sh" primary ;;
  mac4) "$ROOT/scripts/firewall.sh" rollback >/dev/null 2>&1
        "$ROOT/scripts/backend-ctl.sh" B start ;;
  *) bad "this Mac ($(myip)) is not in env.sh"; exit 1 ;;
esac
ok "$(role) at baseline"
