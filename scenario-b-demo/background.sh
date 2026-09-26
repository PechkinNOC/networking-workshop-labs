#!/bin/bash

# Ubuntu 24.04's needrestart apt hook can prompt interactively after any
# package install ("which services to restart?") and hang forever with no
# TTY attached - confirmed live: apt-get install sat blocked for 50+ minutes
# with needrestart/dpkg-status children still running. Force it off.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Simulate systemd-resolved: point resolv.conf to 127.0.0.53
# Docker detects loopback address and replaces it with 8.8.8.8 in containers
cat > /etc/resolv.conf <<'EOF'
nameserver 127.0.0.53
options edns0 trust-ad
EOF

# Ensure Docker daemon has no custom DNS (default behavior), and get
# docker0 up *before* configuring the DNS stub below - the fix at the end
# of this scenario points a container's --dns at docker0's address, so the
# stub needs to actually be listening there, not just on loopback.
apt-get install -y -q dnsmasq 2>/dev/null
rm -f /etc/docker/daemon.json
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true

# Wait for docker0 to actually come up - a fixed sleep isn't reliable enough
DOCKER0_IP=""
for i in $(seq 1 15); do
    DOCKER0_IP=$(ip -4 addr show docker0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    [ -n "$DOCKER0_IP" ] && break
    sleep 1
done

# Start a minimal DNS stub on 127.0.0.53 (host) and docker0's address
# (reachable from any container - this is what "docker run --dns <docker0
# IP>" is meant to hit) so host resolution and the fix both actually work.
# NOTE: upstream is Quad9, not 8.8.8.8/8.8.4.4 - those are the addresses we
# block below (they're what Docker falls back to inside containers). If the
# host's own resolver used the same blocked servers, host DNS - and the
# "docker pull" below - would break too.
LISTEN_ADDRS="127.0.0.53"
[ -n "$DOCKER0_IP" ] && LISTEN_ADDRS="127.0.0.53,${DOCKER0_IP}"
cat > /etc/dnsmasq.conf <<EOF
listen-address=${LISTEN_ADDRS}
bind-interfaces
no-resolv
server=9.9.9.9
server=149.112.112.112
EOF
systemctl stop systemd-resolved 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf &>/tmp/dnsmasq.log &
sleep 1

# Pull the image before blocking egress DNS, so the demo container's
# creation never depends on the (about to be broken) DNS path
docker pull alpine:latest

# Start the demo container and install curl into it - both while 8.8.8.8
# is still reachable, i.e. before the egress block below
docker run -d --name webserver alpine:latest sleep 3600
docker exec webserver apk add --no-cache curl >/tmp/apk-curl.log 2>&1

# Block egress DNS to 8.8.8.8 and 8.8.4.4 - this is what actually breaks
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
iptables -I DOCKER-USER -p udp --dport 53 -d 8.8.4.4 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 8.8.4.4 -j DROP
# Also block on OUTPUT in case anything on the host itself queries these
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 8.8.4.4 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.4.4 -j DROP

echo "done" > /tmp/background-done
