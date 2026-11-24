#!/usr/bin/env bash
# Step 4: HTTPS by NAME, certificate validated, no -k, no IP in the URL
source "$(dirname "$0")/../scripts/lib.sh"
say "TCP to 443, then TLS: ClientHello with SNI, ServerHello, certificate whose SAN contains $APP, key exchange, Finished. Our local CA is trusted, so no warning."
run "$CURL -v $URL/api/status 2>&1 | grep -E 'Connected to|SSL connection|TLSv|subject:|issuer:|subjectAltName|SSL certificate verify|^< HTTP|^< [Xx]-|^\{'"
pause; run "open -a Safari $URL/api/status"
