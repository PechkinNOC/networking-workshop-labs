#!/bin/bash

# Same PMTUD blackhole as demo, two deliberate differences:
#  - different bottleneck MTU (1300, not 1400) - the exact threshold from
#    demo doesn't transfer, has to be found again
#  - ping is ALSO blocked (ICMP echo-request on FORWARD), not just the
#    fragmentation-needed message - so the "ping works, curl doesn't" signal
#    from demo isn't available here. ping just fails outright, which can
#    misleadingly look like a basic connectivity/firewall problem instead of
#    a size-dependent one. curl -I (small) still works fine - that's the
#    real tell.
#
# NOTE: tested broader "block ALL icmp types on OUTPUT" first - it broke the
# demo http.server in a way that looked like a real network effect but did
# not reproduce with any type-specific rule, on either chain, individually.
# Sticking to type-specific rules only (confirmed reliable) rather than
# risk shipping something that may be a sandbox-only artifact.

sysctl -qw net.ipv4.ip_forward=1

ip netns add server
ip link add srv0 type veth peer name srv0p
ip link set srv0p netns server
ip addr add 10.10.50.1/24 dev srv0
ip link set srv0 up mtu 1500
ip netns exec server ip addr add 10.10.50.2/24 dev srv0p
ip netns exec server ip link set srv0p up mtu 1500
ip netns exec server ip link set lo up
ip netns exec server ip route add default via 10.10.50.1

ip netns add client
ip link add cli0 type veth peer name cli0p
ip link set cli0p netns client
ip addr add 10.10.60.1/24 dev cli0
ip link set cli0 up mtu 1300
ip netns exec client ip addr add 10.10.60.2/24 dev cli0p
ip netns exec client ip link set cli0p up mtu 1500
ip netns exec client ip link set lo up
ip netns exec client ip route add default via 10.10.60.1

iptables -I FORWARD -p icmp --icmp-type echo-request -j DROP
iptables -I OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP

mkdir -p /srv/www
python3 -c "print('Hello from the server. ' + 'B' * 6000)" > /srv/www/index.html
python3 -m http.server 8080 --bind 10.10.50.2 --directory /srv/www &>/tmp/httpserver.log &

cat > /usr/local/bin/from-client <<'EOF'
#!/bin/bash
ip netns exec client "$@"
EOF
chmod +x /usr/local/bin/from-client

echo "done" > /tmp/background-done
