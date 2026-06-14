#!/bin/bash

# Create client network namespace
ip netns add client

# Create veth pair: eth1 on server <-> eth1c in client namespace
ip link add eth1 type veth peer name eth1c
ip link set eth1c netns client

# Configure eth1 on the server
ip addr add 10.10.20.1/24 dev eth1
ip link set eth1 up

# Configure client namespace
ip netns exec client ip addr add 10.10.20.100/24 dev eth1c
ip netns exec client ip link set eth1c up
ip netns exec client ip link set lo up

# KEY: Remove direct route for eth1 network, force responses via eth0 (asymmetric routing)
ip route del 10.10.20.0/24 dev eth1 2>/dev/null || true
GW=$(ip route show default | awk '/default/ {print $3; exit}')
if [ -n "$GW" ]; then
    ip route add 10.10.20.0/24 via "$GW"
fi

# Drop INVALID conntrack state
iptables -I FORWARD -m conntrack --ctstate INVALID -j DROP
iptables -I INPUT   -m conntrack --ctstate INVALID -j DROP

# DIFFERENCE from demo: HTTP server listens on 0.0.0.0, not eth1 IP
# ss -tlnp shows 0.0.0.0:8080 — looks fine, misleads the investigator
python3 -m http.server 8080 &>/tmp/httpserver.log &

echo "done" > /tmp/background-done
