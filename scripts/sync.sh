#!/usr/bin/env bash
# After editing env.sh (IPs changed, knob changed): render, commit, push, pull on Mac 2/3,
# and print Mac 4's command.   usage (Mac 1): scripts/sync.sh ["commit message"]
source "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 1
run "scripts/render-configs.sh"; run "scripts/inventory.sh"
git add -A && git commit -qm "${1:-sync configs $(date '+%F %T')}" && echo "committed"
run "git push -q origin main"
on mac2 "git pull -q && git log --oneline -1"
on mac3 "git pull -q && git log --oneline -1"
on mac4 "git pull"
echo "Now restart what reads the changed files (dns-ctl ... restart / edge-ctl ... reload), then scripts/preflight.sh"
