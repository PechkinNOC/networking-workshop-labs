#!/bin/bash

# Ubuntu 24.04's needrestart apt hook can prompt interactively after any
# package install and hang forever with no TTY attached - confirmed live
# on scenario B. Force it off before any apt-get call.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Two loopback aliases: the address DNS will correctly return (1.2.3.4,
# something is actually listening there) and the address the stale
# /etc/hosts entry points at instead (5.6.7.8, nothing listens there ->
# immediate "Connection refused", not a hang).
ip addr add 1.2.3.4/32 dev lo 2>/dev/null
ip addr add 5.6.7.8/32 dev lo 2>/dev/null

# The actual root cause: a stale hosts entry. nsswitch.conf defaults to
# "hosts: files dns" - glibc's getaddrinfo() (used by curl, Python, Go, ...)
# checks /etc/hosts first and never even asks DNS if it finds a match here.
echo "5.6.7.8 api.internal" >> /etc/hosts

# A local DNS stub that answers correctly (1.2.3.4) - deliberately
# DIFFERENT from what's in /etc/hosts, so nslookup/dig (which bypass
# nsswitch and go straight to DNS) shows the "right" answer while the
# actual application-facing path shows something else entirely.
apt-get install -y -q dnsmasq 2>/dev/null
cat > /etc/dnsmasq.conf <<'EOF'
listen-address=127.0.0.1
bind-interfaces
no-resolv
address=/api.internal/1.2.3.4
server=9.9.9.9
EOF
systemctl stop systemd-resolved 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf &>/tmp/dnsmasq.log &
sleep 1
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.1
EOF

# The "correct" service - would work fine if actually reached
mkdir -p /srv/api
echo "OK from the real api.internal" > /srv/api/index.html
python3 -m http.server 8080 --bind 1.2.3.4 --directory /srv/api &>/tmp/httpserver.log &

echo "done" > /tmp/background-done
