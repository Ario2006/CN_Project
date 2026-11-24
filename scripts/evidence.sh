#!/usr/bin/env bash
# Run a command and SAVE its output as text evidence (with date, host, IP, exact command).
#   scripts/evidence.sh <evidence/folder/name.txt> <command ...>
#   e.g. scripts/evidence.sh evidence/09_BACKUP_DNS/09_DNS_via_backup.txt scripts/dns-failover-check.sh --flush
source "$(dirname "$0")/lib.sh"
OUT="${1:?usage: evidence.sh <file.txt> <command...>}"; shift
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT";; esac; mkdir -p "$(dirname "$OUT")"
{ echo "# $(date '+%F %T') | host $(hostname -s) | IP $(myip) | role $(role)"; echo "# \$ $*"; echo; } > "$OUT"
"$@" 2>&1 | sed $'s/\033\\[[0-9;]*m//g' | tee -a "$OUT"
echo "saved -> ${OUT#$ROOT/}"
