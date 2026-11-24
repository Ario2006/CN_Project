#!/usr/bin/env bash
# Step 5: load balancing across both backends (X-Backend alternates)
source "$(dirname "$0")/../scripts/lib.sh"
say "nginx round-robins the upstream pool: A, B, A, B. The client never sees a backend IP - only the edge."
for i in 1 2 3 4 5 6; do run "$CURL -s -o /dev/null -D - $URL/api/status | grep -iE '^x-backend|^x-edge' | tr -d '\r' | paste -sd' ' -"; done
say "Mac 2's access log shows which upstream IP:port served each request."
on mac2 "tail -n 6 /tmp/nginx-cn-access.log"
