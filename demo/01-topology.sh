#!/usr/bin/env bash
# Step 1: topology + IP/service inventory
source "$(dirname "$0")/../scripts/lib.sh"
say "Four Macs, one Wi-Fi subnet $SUBNET. Clients only know the name $APP; DNS sends them to the edge, the edge balances two backends."
run "open '$ROOT/docs/topology.png'"
hdr "IP / service inventory (live from env.sh)"
printf '%-6s %-10s %-15s %-48s %s\n' Mac Person IP Services "Cloud analogue"
printf '%-6s %-10s %-15s %-48s %s\n' 1 Aryan "$MAC1_IP" "dnsmasq primary DNS udp/53, test client" "Route 53 private zone"
printf '%-6s %-10s %-15s %-48s %s\n' 2 Ranajeet "$MAC2_IP" "nginx edge: TLS tcp/$HTTPS_PORT, load balancer" "ALB / CloudFront edge"
printf '%-6s %-10s %-15s %-48s %s\n' 3 Abhijeet "$MAC3_IP" "Backend A tcp/$BACKEND_A_PORT, backup DNS, standby edge" "EC2 A, 2nd resolver, standby LB"
printf '%-6s %-10s %-15s %-48s %s\n' 4 Ankita "$MAC4_IP" "Backend B tcp/$BACKEND_B_PORT, test client" "EC2 B"
echo "Subnet $SUBNET  mask $NETMASK  gateway $GATEWAY  domain $DOMAIN  TTL ${DNS_TTL}s"
