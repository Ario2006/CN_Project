#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
BACKEND_ID=A PORT=3001 exec python3 server.py
