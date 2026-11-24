# Mac 4 (Ankita): command card

Mac 4 = **Backend B (TCP 3002) + test client**. Run every command from inside your `CN_Project` folder.
Each command prints its result. If you see `FAIL`, read the line out to Aryan.

## Before the evaluation (once)
```bash
git pull                              # latest scripts and configs
caffeinate -dis &                     # keep the Mac awake (no sleep mid-demo)
ipconfig getifaddr en0                # tell Aryan this IP if it changed
scripts/backend-ctl.sh B start        # expect: Backend B LISTENING on *:3002, X-Backend: B
sudo scripts/set-client-dns.sh both   # expect: networksetup: <Mac1 IP> <Mac3 IP>
scripts/preflight.sh                  # expect: ALL GREEN
```

## During the demo: only when Aryan says so

| Aryan says | You run | You should see |
|---|---|---|
| "Ankita, firewall ON" (Ext C) | `scripts/firewall.sh apply` | `Isolation ACTIVE on Backend B ... only <Mac2 IP> may reach port 3002` |
| "Ankita, firewall OFF" (Ext C) | `scripts/firewall.sh rollback` | `Isolation REMOVED` |
| "Ankita, stop B" | `scripts/backend-ctl.sh B stop` | `stopped Backend B` |
| "Ankita, start B" | `scripts/backend-ctl.sh B start` | `Backend B LISTENING on *:3002` |
| "Ankita, show your backend" | `scripts/backend-ctl.sh B status` and `lsof -nP -iTCP:3002 -sTCP:LISTEN` | `*:3002 (LISTEN)`, not 127.0.0.1 |
| "Ankita, test as a client" | `scripts/diagnose.sh` | `ALL LAYERS OK end-to-end` |
| "Ankita, resolve the name" | `dig app.teamTeamCN.test` | ANSWER `30 IN A <Mac2 IP>`, SERVER = Mac 1 |
| "Ankita, reset" | `scripts/reset-baseline.sh` | `mac4 at baseline` |

## If something breaks on Mac 4
- `scripts/backend-ctl.sh B status` shows NOT listening → `scripts/backend-ctl.sh B start`
- The firewall might still be on → `scripts/firewall.sh status`, then `scripts/firewall.sh rollback`
- The name doesn't resolve → `sudo scripts/set-client-dns.sh both`

## What you must be able to explain (viva)
- Why B binds to `0.0.0.0` (all interfaces) rather than `127.0.0.1`: otherwise Mac 2 can't reach it over the LAN.
- What `X-Backend: B` proves: which backend served the request, even though the client only talked to the edge.
- Firewall on (Ext C): your Mac drops TCP to 3002 from everyone except Mac 2. Clients time out, and the edge still works.
- If you stop B, nginx retries the request on A, so the client still gets 200. After 10 s (`fail_timeout`), nginx tries B again.
