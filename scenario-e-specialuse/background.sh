#!/bin/bash

# NOT fully verified end-to-end live before shipping (unlike every other
# scenario in this workshop) - this sandbox has no real root over apt/dpkg
# locks, so none of this could be dry-run here. The mechanism is instead
# verified two ways:
#   1. Reading unbound's own source (services/localzone.c, daemon/worker.c):
#      default special-use zones (test./invalid./onion./...) are type
#      "static" and local_zones_answer() runs BEFORE any forwarding logic -
#      if it intercepts the query, forwarding is never even attempted.
#   2. unbound-host's own manpage: by default it does NOT read
#      /etc/resolv.conf at all (independent root-based resolution); "-r"
#      makes it use resolv.conf's forwarders - but the built-in local-zone
#      check still runs first regardless, so even "-r" doesn't help.
#   3. This mirrors a real incident (user's own mailmachine/testenv):
#      opendkim, which embeds libunbound directly for its own DNS lookups,
#      never saw the properly-configured recursive resolver (mm-dns) at
#      all - same class of problem, this scenario reproduces the general
#      shape of it with the (much lighter) standalone unbound-host tool.
#
# First real test of this file happens live on Killercoda.

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

apt-get install -y -q dnsmasq unbound-host 2>/dev/null

# The internal .test domain, correctly served by the system resolver -
# ordinary tools (dig, getent, curl) all see this fine.
ip addr add 10.77.0.5/32 dev lo 2>/dev/null
cat > /etc/dnsmasq.conf <<'EOF'
listen-address=127.0.0.1
bind-interfaces
no-resolv
address=/test/10.77.0.5
server=9.9.9.9
EOF
systemctl stop systemd-resolved 2>/dev/null || true
# Installing the dnsmasq package auto-starts its own systemd service, which
# grabs 127.0.0.1:53 before our own instance gets a chance to - confirmed
# live: "failed to create listening socket for 127.0.0.1: Address already
# in use". Stop it first.
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf &>/tmp/dnsmasq.log &
sleep 1
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.1
EOF

mkdir -p /srv/db1
echo "OK from db1.test" > /srv/db1/index.html
python3 -m http.server 8080 --bind 10.77.0.5 --directory /srv/db1 &>/tmp/httpserver.log &

echo "done" > /tmp/background-done
