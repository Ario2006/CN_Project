#!/usr/bin/env bash
# Step 7: HTTP headers + caching (Cache-Control, ETag, 304)
source "$(dirname "$0")/../scripts/lib.sh"
say "Cache-Control max-age=60 means a FRESH copy can be reused for 60 s with no network at all; ETag lets the client revalidate."
run "$CURL -sI $URL/api/cache | grep -iE 'HTTP/|cache-control|etag|x-backend'"; pause
say "Conditional request: the client sends the ETag back; unchanged -> 304 Not Modified, headers only, no body."
run "$CURL -si -H 'If-None-Match: \"phase1-cache-v1\"' $URL/api/cache | grep -iE 'HTTP/|etag|content-length'"
say "Fresh hit = no request at all. Conditional = round trip, tiny 304. Full request = 200 with the whole body."
