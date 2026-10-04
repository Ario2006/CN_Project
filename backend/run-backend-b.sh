#!/usr/bin/env bash
# Backend B runner - runs on Mac 4 (Ankita, 10.7.5.46, port 3002)
# Hostname: Ankitas-MacBook-Pro | Interface: en0
# Subnet: 10.7.0.0/19 | Netmask: 255.255.224.0 (0xffffe000) | Gateway: 10.7.0.1
# MAC (on-the-air): da:8e:64:df:05:3f | MAC (hardware): 10:9f:41:c6:2a:38
cd "$(dirname "$0")" || exit 1
BACKEND_ID=B PORT=3002 exec python3 server.py
