#!/bin/bash

# Scenario A: multi-homed server with asymmetric routing.
#
# Topology:
#   client ns: "remote" client 10.10.30.100 sits behind a router 10.10.20.100
#   server:    eth1 (10.10.20.1/24) faces the client router,
#              default route goes out of the primary interface (cloud gateway)
#
# Requests arrive on eth1, but the server has no route back to 10.10.30.0/24
# except the default one -> replies leave through the primary interface
# and never reach the client.

# Client network namespace
ip netns add client

# Veth pair: eth1 on the server <-> eth1c in the client namespace
ip link add eth1 type veth peer name eth1c
ip link set eth1c netns client

# Server side
ip addr add 10.10.20.1/24 dev eth1
ip link set eth1 up

# Client side: router address 10.10.20.100, the "remote client" address 10.10.30.100 on lo
ip netns exec client ip addr add 10.10.20.100/24 dev eth1c
ip netns exec client ip addr add 10.10.30.100/32 dev lo
ip netns exec client ip link set eth1c up
ip netns exec client ip link set lo up
# Traffic towards the server is sourced from 10.10.30.100
ip netns exec client ip route replace 10.10.20.0/24 dev eth1c src 10.10.30.100

# Loose reverse-path filter: packets from 10.10.30.100 are accepted on eth1
# (a route back exists, just not via eth1), which is what makes the problem silent
sysctl -qw net.ipv4.conf.all.rp_filter=2
sysctl -qw net.ipv4.conf.default.rp_filter=2
sysctl -qw net.ipv4.conf.eth1.rp_filter=2

# HTTP server bound to the eth1 address only
python3 -m http.server 8080 --bind 10.10.20.1 &>/tmp/httpserver.log &

# Transparent wrapper - participants use "from-client <cmd>" instead of "ip netns exec client <cmd>"
cat > /usr/local/bin/from-client <<'EOF'
#!/bin/bash
ip netns exec client "$@"
EOF
chmod +x /usr/local/bin/from-client

echo "done" > /tmp/background-done
