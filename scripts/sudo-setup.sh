#!/usr/bin/env bash
# Lets THIS user run only the project's admin tools without a password prompt,
# so the scripts work over SSH. Nothing else gets passwordless root.
#   install : bash scripts/sudo-setup.sh install   (asks your sudo password ONCE)
#   remove  : bash scripts/sudo-setup.sh remove    (run after the evaluation)
#   show    : bash scripts/sudo-setup.sh show
set -euo pipefail
F=/etc/sudoers.d/cn-project
U="$(id -un)"
case "${1:-show}" in
  install)
    T="$(mktemp)"
    cat > "$T" <<EOS
# CN project (temporary) - remove with: bash scripts/sudo-setup.sh remove
Cmnd_Alias CN_TOOLS = /opt/homebrew/bin/nginx, /opt/homebrew/sbin/dnsmasq, /sbin/pfctl, \\
  /usr/bin/pkill, /usr/sbin/networksetup, /usr/bin/dscacheutil, /usr/bin/killall, \\
  /usr/sbin/tcpdump, /usr/sbin/lsof
$U ALL=(root) NOPASSWD: CN_TOOLS
EOS
    /usr/sbin/visudo -cf "$T" >/dev/null || { echo "sudoers syntax error, nothing installed"; exit 1; }
    sudo install -m 0440 -o root -g wheel "$T" "$F"; rm -f "$T"
    echo "installed $F for $U"; sudo -n -l 2>/dev/null | grep -A3 NOPASSWD || true ;;
  remove) sudo rm -f "$F" && echo "removed $F" ;;
  show)   [ -f "$F" ] && cat "$F" || echo "not installed" ;;
  *) echo "usage: sudo-setup.sh install|remove|show"; exit 1 ;;
esac
