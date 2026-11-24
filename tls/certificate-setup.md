# TLS setup notes (Mac 2 = CA + cert owner; mkcert is faculty-approved)

## Host & Network Parameters
- **CA Root & Leaf Owner:** Mac 2 (Ranajeet, `Ranajeets-MacBook-Pro`)
  - **IPv4:** `10.7.7.179`
  - **Subnet / Netmask:** `10.7.0.0/19` (Mask: `255.255.224.0`, Hex: `0xffffe000`)
  - **MAC (on the air):** `06:a4:46:65:eb:bd`
  - **MAC (hardware):** `10:9f:41:bb:a2:9f`
- **Relying Clients (Trusted Root in System Keychain):**
  - Mac 1 (Aryan): `10.7.30.82` | Air MAC: `de:ee:5b:31:fc:1a` | HW MAC: `10:9f:41:be:57:6d`
  - Mac 3 (Abhijeet): `10.7.2.73` | Air MAC: `8e:c9:23:39:6e:c1` | HW MAC: `10:9f:41:c0:b2:b1`
  - Mac 4 (Ankita): `10.7.5.46` | Air MAC: `da:8e:64:df:05:3f` | HW MAC: `10:9f:41:c6:2a:38`

---

## Setup Steps

1. `brew install mkcert` (Mac 2). `mkcert -install` creates a local CA and trusts it on Mac 2.
2. In `tls/`: `source ../env.sh; mkcert -cert-file edge.pem -key-file edge-key.pem app.$DOMAIN api.$DOMAIN`
3. Copy `edge.pem` + `edge-key.pem` to `$(brew --prefix)/etc/nginx/certs/` (path referenced by `nginx.conf`).
4. Export the PUBLIC CA cert: `cp "$(mkcert -CAROOT)/rootCA.pem" tls/rootCA.pem` and commit it.
   NEVER share or commit `rootCA-key.pem` or `edge-key.pem` (gitignored: `*-key.pem`).
5. Every other Mac trusts the CA:
   `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain tls/rootCA.pem`
6. Verify SAN: `openssl x509 -in tls/edge.pem -noout -text | grep -A1 "Subject Alternative Name"`
   - Confirmed SAN: `DNS:app.teamX.test, DNS:api.teamX.test`
7. Verify trust end-to-end (no -k): `/usr/bin/curl -v https://app.$DOMAIN/api/status`

Rollback: `sudo security remove-trusted-cert -d tls/rootCA.pem` (per client); on Mac 2 also `mkcert -uninstall`.
Why a CA instead of a bare self-signed leaf: clients trust ONE root, which can sign many certs (app, api, standby edge in Phase 2).

---

## Phase 2 changes (24 Nov 2026)
1. **Leaf reissued for the real team domain.** The installed leaf still named `app.teamX.test`. On Mac 2, with the **same mkcert CA** (so client trust is unchanged):
   `cd /opt/homebrew/etc/nginx/certs && mkdir -p old && cp edge.pem edge-key.pem old/ && mkcert -cert-file edge.pem -key-file edge-key.pem app.teamTeamCN.test api.teamTeamCN.test`
   Verify: `/usr/bin/curl -v https://app.teamTeamCN.test/api/status 2>&1 | grep -E 'subjectAltName|verify ok'` gives `host "app.teamTeamCN.test" matched`, `SSL certificate verify ok`.
2. **Standby edge (Mac 3, Ext E) uses the same leaf and key**, copied from Mac 2 (run on Mac 1; it uses SSH keys, no password):
   `ssh mac3 'mkdir -p /opt/homebrew/etc/nginx/certs' && scp -3 mac2:/opt/homebrew/etc/nginx/certs/edge.pem mac2:/opt/homebrew/etc/nginx/certs/edge-key.pem mac3:/opt/homebrew/etc/nginx/certs/`
   No new certificate is needed for the DNS cutover: the SAN binds the **name**, not the IP.
   The key was deleted from Mac 3 after rehearsal. Copy it again before the Ext E demo, and delete it afterwards: `ssh mac3 'rm /opt/homebrew/etc/nginx/certs/edge-key.pem'`.
3. The CA's label still reads `…@app.teamX.test`. That's only the name mkcert gave the CA at creation; trust comes from its key in the System keychain.
