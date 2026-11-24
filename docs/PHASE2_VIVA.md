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
