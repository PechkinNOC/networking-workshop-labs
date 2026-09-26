#!/bin/bash

# Simulate systemd-resolved: point resolv.conf to 127.0.0.53
# Docker detects loopback address and replaces it with 8.8.8.8 in containers
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.53
options edns0 trust-ad
EOF

# Start a minimal DNS stub on 127.0.0.53 so host resolution works
# (simulates systemd-resolved on the host)
# NOTE: upstream is Quad9, not 8.8.8.8/1.1.1.1 - those are the addresses we
# block below (they're what Docker falls back to inside containers). If the
# host's own resolver used the same blocked servers, host DNS - and the
# "docker pull" below - would break too.
apt-get install -y -q dnsmasq 2>/dev/null
cat > /etc/dnsmasq.conf <<'EOF'
listen-address=127.0.0.53
bind-interfaces
no-resolv
server=9.9.9.9
server=149.112.112.112
EOF
systemctl stop systemd-resolved 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf &>/tmp/dnsmasq.log &

# Ensure Docker daemon has no custom DNS (default behavior)
rm -f /etc/docker/daemon.json
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true

sleep 3

# Pull the image before blocking egress DNS, so the demo container's
# creation never depends on the (about to be broken) DNS path
docker pull alpine:latest

# Start the demo container and install curl into it - both while 8.8.8.8
# is still reachable, i.e. before the egress block below
docker run -d --name webserver alpine:latest sleep 3600
docker exec webserver apk add --no-cache curl >/tmp/apk-curl.log 2>&1

# Block egress DNS to 8.8.8.8 and 1.1.1.1 - this is what actually breaks
# the container (Docker's fallback resolver), not the host.
#
# IMPORTANT: container traffic is routed/NAT'd, not locally-originated, so
# it never passes through OUTPUT - only through FORWARD/DOCKER-USER. A rule
# on OUTPUT alone silently does nothing for container DNS (confirmed on a
# live run: nslookup from the container reached 8.8.8.8 fine, counters
# stayed at 0). DOCKER-USER is Docker's own hook for exactly this, and
# survives daemon restarts unlike hand-edited FORWARD rules.
iptables -I DOCKER-USER -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I DOCKER-USER -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 1.1.1.1 -j DROP
# Also block on OUTPUT in case anything on the host itself queries these
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 1.1.1.1 -j DROP

echo "done" > /tmp/background-done
