#!/usr/bin/env bash
# Step 10 / Ext F: diagnose the examiner's fault bottom-up
source "$(dirname "$0")/../scripts/lib.sh"
say "Method: name -> IP -> TCP port -> TLS -> HTTP -> backend. Each layer depends on the one below; the first failing layer is the cause."
run "'$ROOT/scripts/diagnose.sh' ${1:-}"
say "If it is behind the edge (502), check the edge itself:"
on mac2 "scripts/diagnose-edge.sh"
