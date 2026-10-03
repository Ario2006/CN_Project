#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
BACKEND_ID=B PORT=3002 exec python3 server.py
