#!/bin/bash

# Topology: client (netns) -- veth MTU 1400 -- HOST (router, this machine,
# ip_forward=1) -- veth MTU 1500 -- server (netns).
#
# The bottleneck (1400) sits on the ROUTER's own client-facing interface -
# NOT on the client's own interface. This matters: if the small MTU were on
# the client's own link, the client would advertise a correspondingly small
# MSS in its SYN and the server would simply never send oversized segments -
# no PMTUD needed, nothing would ever break (verified in an isolated netns:
# putting the bottleneck on the client's own veth end never reproduced any
# hang at all). The real PMTUD blackhole only happens when the smaller MTU
# is on a link NEITHER endpoint's own interface reports - a router in the
# middle (a VPN/tunnel hop, typically) that neither side's MSS negotiation
# ever sees.

sysctl -qw net.ipv4.ip_forward=1

# --- server side: normal 1500 MTU throughout ---
ip netns add server
ip link add srv0 type veth peer name srv0p
ip link set srv0p netns server
ip addr add 10.10.50.1/24 dev srv0
ip link set srv0 up mtu 1500
ip netns exec server ip addr add 10.10.50.2/24 dev srv0p
ip netns exec server ip link set srv0p up mtu 1500
ip netns exec server ip link set lo up
ip netns exec server ip route add default via 10.10.50.1

# --- client side: the client's OWN interface is a normal 1500 - it has no
# idea anything is wrong. The bottleneck (1400) is only on the router's
# (this host's) side of that link. ---
ip netns add client
ip link add cli0 type veth peer name cli0p
ip link set cli0p netns client
ip addr add 10.10.60.1/24 dev cli0
ip link set cli0 up mtu 1400
ip netns exec client ip addr add 10.10.60.2/24 dev cli0p
ip netns exec client ip link set cli0p up mtu 1500
ip netns exec client ip link set lo up
ip netns exec client ip route add default via 10.10.60.1

# The actual break: block the router's own outgoing "fragmentation needed"
# ICMP (someone hardened the firewall against "ping floods" and swept this
# up too). Verified live: this is what makes the server retransmit the same
# oversized segment forever instead of shrinking it after one round trip.
iptables -I OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP

# Server: a page whose body is bigger than a single 1400-MTU segment can
# carry, so a real transfer is guaranteed to hit the bottleneck.
mkdir -p /srv/www
python3 -c "print('Hello from the server. ' + 'A' * 6000)" > /srv/www/index.html
ip netns exec server python3 -m http.server 8080 --bind 10.10.50.2 --directory /srv/www &>/tmp/httpserver.log &

# Transparent wrapper - participants use "from-client <cmd>" instead of "ip netns exec client <cmd>"
cat > /usr/local/bin/from-client <<'EOF'
#!/bin/bash
ip netns exec client "$@"
EOF
chmod +x /usr/local/bin/from-client

echo "done" > /tmp/background-done
