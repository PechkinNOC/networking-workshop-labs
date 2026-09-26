#!/bin/bash

# Install unbound as local DNS cache
apt-get install -y -q unbound 2>/dev/null

# Configure unbound to listen on 127.53.53.53 (non-standard loopback address)
cat > /etc/unbound/unbound.conf.d/workshop.conf <<'EOF'
server:
    interface: 127.53.53.53
    access-control: 127.0.0.0/8 allow
    do-daemonize: no
    logfile: /tmp/unbound.log

forward-zone:
    name: "."
    forward-addr: 9.9.9.9
    forward-addr: 149.112.112.112
EOF
# NOTE: upstream is Quad9, not 8.8.8.8/1.1.1.1 - those are the addresses we
# block below (they're what Docker falls back to inside containers). If the
# host's own resolver used the same blocked servers, host DNS - and the
# "docker pull" below - would break too.

systemctl stop systemd-resolved 2>/dev/null || true
systemctl restart unbound 2>/dev/null || unbound -c /etc/unbound/unbound.conf 2>/dev/null || true

# Point resolv.conf to the non-standard loopback address
cat > /etc/resolv.conf <<'EOF'
nameserver 127.53.53.53
EOF

# Configure Docker with non-standard docker0 bridge
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "bip": "172.31.0.1/24"
}
EOF

systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
sleep 3

# Pull the image before blocking egress DNS, so the demo container's
# creation never depends on the (about to be broken) DNS path
docker pull alpine:latest

# Start the container and install curl into it - both while 8.8.8.8 is
# still reachable, i.e. before the egress block below
docker run -d --name webserver alpine:latest sleep 3600
docker exec webserver apk add --no-cache curl >/tmp/apk-curl.log 2>&1

# Same egress DROP as demo. IMPORTANT: container traffic is routed/NAT'd,
# not locally-originated, so it never passes through OUTPUT - only through
# FORWARD/DOCKER-USER. DOCKER-USER is Docker's own hook for this and
# survives daemon restarts unlike hand-edited FORWARD rules.
iptables -I DOCKER-USER -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I DOCKER-USER -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 1.1.1.1 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 1.1.1.1 -j DROP

echo "done" > /tmp/background-done
