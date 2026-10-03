# TLS setup notes (Mac 2 = CA + cert owner; mkcert is faculty-approved)

1. `brew install mkcert` (Mac 2). `mkcert -install` creates a local CA and trusts it on Mac 2.
2. In `tls/`: `source ../env.sh; mkcert -cert-file edge.pem -key-file edge-key.pem app.$DOMAIN api.$DOMAIN`
3. Copy `edge.pem` + `edge-key.pem` to `$(brew --prefix)/etc/nginx/certs/` (path referenced by nginx.conf).
4. Export the PUBLIC CA cert: `cp "$(mkcert -CAROOT)/rootCA.pem" tls/rootCA.pem` and commit it.
   NEVER share or commit `rootCA-key.pem` or `edge-key.pem` (gitignored: `*-key.pem`).
5. Every other Mac trusts the CA:
   `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain tls/rootCA.pem`
6. Verify SAN: `openssl x509 -in tls/edge.pem -noout -text | grep -A1 "Subject Alternative Name"`
7. Verify trust end-to-end (no -k): `/usr/bin/curl -v https://app.$DOMAIN/api/status`

Rollback: `sudo security remove-trusted-cert -d tls/rootCA.pem` (per client); on Mac 2 also `mkcert -uninstall`.
Why a CA instead of a bare self-signed leaf: clients trust ONE root, which can sign many certs (app, api, standby edge in Phase 2).
