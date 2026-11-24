#!/usr/bin/env bash
# Step 0 (before the examiner arrives): everything green?
source "$(dirname "$0")/../scripts/lib.sh"
run "'$ROOT/scripts/preflight.sh'"
