#!/usr/bin/env bash
# Ext D: same as step 8 (stop A -> all B -> A back -> balancing resumes) + SPOF statement
exec "$(dirname "$0")/08-backend-fail.sh"
