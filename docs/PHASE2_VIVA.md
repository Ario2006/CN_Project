# Phase 2 viva prep (every member should be able to answer all of these)

**Backup DNS (A)**
1. *How does the client decide to use the backup?* The resolver list is ordered. If the first server doesn't answer (timeout) or returns ICMP port-unreachable (dnsmasq stopped but the host is up), the macOS resolver sends the query to the next one.
2. *Why flush before testing failover?* The client would otherwise answer from its cache for up to 30 s without sending any query, so it would prove nothing.
3. *What's the danger with two DNS servers?* They can drift: different records give different answers depending on which server responds. We render both from one `env.sh`.
4. *DNS failure vs app failure?* DNS down gives "Could not resolve host": no IP, no TCP at all. App down means resolution, TCP and TLS work and the edge returns 502.
5. *Primary vs secondary in real DNS?* Real setups use zone transfers (AXFR/IXFR) from a primary to secondaries. We simply deploy the same config to both. Route 53 runs anycast name servers across many locations.

**TTL (B)**
6. *What is a TTL?* The number of seconds a resolver or cache may reuse an answer without asking again. It's set by the authoritative server (`local-ttl=30`).
7. *Why did dig show the new IP while curl still used the old one?* dig queries the server directly with no cache. curl uses the OS resolver (mDNSResponder), which had cached the old answer.
8. *Why isn't the stale period always exactly 30 s?* The timer started when the client last fetched the record, not when we changed it.
9. *Trade-off of a low TTL?* Faster cutover, but more queries, more load and more dependence on DNS being up. A high TTL is more resilient but changes slowly.
10. *How do you migrate safely?* Lower the TTL at least one old TTL in advance, switch the record, keep the old endpoint running for at least one TTL while it drains, then raise the TTL again.

**Isolation (C)**
11. *Why pf rather than the macOS firewall?* The Application Firewall works per app. pf filters by IP, port and protocol, statefully.
12. *Drop vs reject?* Drop gives the client a timeout and reveals nothing. Reject (RST) gives "connection refused" quickly but confirms the host exists.
13. *How do replies reach Mac 2 if everything else to 3001 is blocked?* `keep state`: pf matches return packets to the allowed connection's state entry.
14. *Defense in depth: why isolate if clients "never use" backend IPs?* Convention isn't enforcement. A compromised or misconfigured client could bypass the edge and skip TLS, logging and load balancing.
15. *Cloud equivalent?* Security groups or NACLs: the backend SG allows the port only from the ALB's SG.

**HA (D)**
16. *Passive vs active health checks?* Passive (open-source nginx) learns from real failures: `max_fails` within `fail_timeout`. Active probes periodically (nginx Plus, HAProxy, ALB).
17. *Why did the client see no error when A died?* `proxy_next_upstream error` retried the same request on B before replying.
18. *What do `upstream=A:3001, B:3002 upstream_status=502, 200` mean?* The first attempt to A failed, the retry on B succeeded, and the client got the 200.
19. *Remaining SPOF?* The edge (Mac 2), plus the Wi-Fi AP/LAN. Fix it with a redundant edge plus VRRP floating IP, health-checked DNS, or anycast / a managed multi-AZ load balancer.
20. *Why does load balancing come back on its own?* After `fail_timeout` (10 s), nginx tries A again with real traffic and resets the counter on success.

**Edge cutover (E)**
21. *Why did the standby need no new certificate?* The certificate's SAN names `app.teamTeamCN.test`. TLS validates the name the client asked for, not the IP.
22. *Why keep the old edge running?* Clients with a cached answer still connect there until the TTL expires.
23. *DNS failover vs floating IP?* DNS failover works across networks but is slowed by TTL and caching. A floating IP moves in about 1 s but only within one L2 segment, using gratuitous ARP.
24. *Is the TLS session carried over?* No. Clients do a fresh TCP handshake and TLS handshake with the standby.

**Troubleshooting (F)**
25. *Your diagnosis order and why?* Name, IP, port, TLS, HTTP, backend. Each layer depends on the one below it, so the first failing layer is the cause.
26. *Refused vs timeout?* Refused means the host is alive and sent a RST, so nothing is listening. Timeout means no reply at all: host down, wrong IP, or a firewall dropping packets.
27. *dig works but curl fails to resolve: why?* `/etc/hosts`, a different resolver for curl (scoped resolvers or VPN), or the cache. dig bypasses the OS resolver.
28. *What does a 502 tell you?* DNS, TCP and TLS to the edge all succeeded. The edge couldn't get a valid response from any upstream.

**Learned while building: likely follow-ups**
29. *Your failover log shows 504, not "connection refused". Why?* Mac 3's macOS firewall drops SYNs to a closed port instead of sending an RST, so nginx's 1 s `proxy_connect_timeout` fires (504 in `upstream_status`). nginx still retries on B in the same request. Without that firewall you'd see an instant RST and `connect() failed (61: Connection refused)`.
30. *Why was the client stale for 37 s with a 30 s TTL?* The cache entry was created at the client's last lookup, slightly before the change, and mDNSResponder expires and refreshes entries lazily. Expect roughly one TTL, not to the second.
31. *What happens if a client also lists 8.8.8.8?* 8.8.8.8 doesn't know `.test` and answers NXDOMAIN. macOS can use that answer and cache it negatively, so our name stops resolving even though our servers are fine. We saw this happen.
32. *An upstream port typo didn't produce any error for users. How would you catch it?* Failover hides it. Look at the X-Backend distribution (only B), the access log (`upstream_status=502, 200`) and `diagnose-edge.sh` (TCP to `:3011` refused). Monitoring must alert on upstream failures, not just on client errors.
33. *Why does a DNS cutover need no new certificate?* The certificate's SAN lists `app.teamTeamCN.test`. TLS checks the name the client asked for, so any edge holding that cert and key is valid.
34. *How is pf rollback guaranteed?* The rules live only in the anchor `com.apple/250.CNIsolation`. Rollback flushes that anchor and releases our `pfctl -E` reference token. The original `/etc/pf.conf` is never edited, and a copy is in `firewall/backup/`.
35. *Why not keep the campus DNS as the upstream?* It was unreachable on test day, and that broke internet names only. Our zone is answered locally (`local=`), so it was never affected: a nice example of failure isolation.
36. *What does `/edge-health` prove?* It's answered by nginx itself without touching any backend. If it returns 200 while `/api/status` returns 502, the edge is healthy and the fault is behind it.
37. *The issuer says `…@app.teamX.test`. Isn't your domain teamTeamCN?* That's only the **label** mkcert gave the CA when it was created (user@hostname at the time). Trust comes from the CA's **key** being in each Mac's System keychain, not from its name. The **leaf** certificate's SAN is what must match, and it lists `app.teamTeamCN.test` and `api.teamTeamCN.test` (curl: `subjectAltName: host "app.teamTeamCN.test" matched`).
