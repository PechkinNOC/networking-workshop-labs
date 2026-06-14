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
    forward-addr: 8.8.8.8
    forward-addr: 1.1.1.1
EOF

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

# Same egress DROP as demo
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 1.1.1.1 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 1.1.1.1 -j DROP

# Start a container — DNS will be broken inside
docker run -d --name webserver alpine:latest sleep 3600

echo "done" > /tmp/background-done
