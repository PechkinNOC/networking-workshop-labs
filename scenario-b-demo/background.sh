#!/bin/bash

# Simulate systemd-resolved: point resolv.conf to 127.0.0.53
# Docker detects loopback address and replaces it with 8.8.8.8 in containers
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.53
options edns0 trust-ad
EOF

# Start a minimal DNS stub on 127.0.0.53 so host resolution works
# (simulates systemd-resolved on the host)
apt-get install -y -q dnsmasq 2>/dev/null
cat > /etc/dnsmasq.conf <<'EOF'
listen-address=127.0.0.53
bind-interfaces
no-resolv
server=8.8.8.8
server=1.1.1.1
EOF
systemctl stop systemd-resolved 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf &>/tmp/dnsmasq.log &

# Block egress DNS to 8.8.8.8 and 1.1.1.1
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 1.1.1.1 -j DROP

# Ensure Docker daemon has no custom DNS (default behavior)
rm -f /etc/docker/daemon.json
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true

sleep 3

# Start a long-running container to demonstrate the problem
docker run -d --name webserver alpine:latest sleep 3600

echo "done" > /tmp/background-done
