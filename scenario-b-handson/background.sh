#!/bin/bash

# Ubuntu 24.04's needrestart apt hook can prompt interactively after any
# package install ("which services to restart?") and hang forever with no
# TTY attached - confirmed live on scenario B: apt-get install sat blocked
# for 50+ minutes with needrestart/dpkg-status children still running.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

apt-get install -y -q unbound 2>/dev/null

# Configure Docker with a non-standard docker0 bridge, and bring it up
# *before* configuring unbound below - the fix for this scenario points a
# container's --dns at docker0's address, so unbound needs to actually be
# listening there, not just on the loopback stub address.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "bip": "172.31.0.1/24"
}
EOF
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true

# Wait for docker0 to actually come up - a fixed sleep isn't reliable enough
DOCKER0_IP=""
for i in $(seq 1 15); do
    DOCKER0_IP=$(ip -4 addr show docker0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    [ -n "$DOCKER0_IP" ] && break
    sleep 1
done

# This Killercoda image runs its own dnsmasq (unrelated to this scenario,
# not managed by systemd) that already owns docker0's gateway address in
# the default-bridge case - confirmed live on scenario B demo: our own
# resolver failed with "Address already in use". Add a second address on
# docker0 (its own gateway's octet, swapped to .53) that didn't exist yet
# when that platform dnsmasq started, and bind there instead - still
# on-link and reachable from any container.
STUB_IP="$DOCKER0_IP"
if [ -n "$DOCKER0_IP" ]; then
    STUB_IP="${DOCKER0_IP%.*}.53"
    ip addr add "${STUB_IP}/32" dev docker0 2>/dev/null || true
fi

# Configure unbound to listen on 127.53.53.53 (non-standard loopback address)
# and on the docker0 alias address above (don't hardcode 172.31.0.1 - this
# env is exactly what teaches "check, don't guess")
DOCKER0_IFACE_LINE=""
[ -n "$DOCKER0_IP" ] && DOCKER0_IFACE_LINE="    interface: ${STUB_IP}"
cat > /etc/unbound/unbound.conf.d/workshop.conf <<EOF
server:
    interface: 127.53.53.53
${DOCKER0_IFACE_LINE}
    access-control: 127.0.0.0/8 allow
    access-control: 172.16.0.0/12 allow
    do-daemonize: no
    logfile: /tmp/unbound.log

forward-zone:
    name: "."
    forward-addr: 9.9.9.9
    forward-addr: 149.112.112.112
EOF
# NOTE: upstream is Quad9, not 8.8.8.8/8.8.4.4 - those are the addresses we
# block below (they're what Docker falls back to inside containers). If the
# host's own resolver used the same blocked servers, host DNS - and the
# "docker pull" below - would break too.

systemctl stop systemd-resolved 2>/dev/null || true
systemctl restart unbound 2>/dev/null || unbound -c /etc/unbound/unbound.conf 2>/dev/null || true

# Point resolv.conf to the non-standard loopback address
cat > /etc/resolv.conf <<'EOF'
nameserver 127.53.53.53
EOF

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
iptables -I DOCKER-USER -p udp --dport 53 -d 8.8.4.4 -j DROP
iptables -I DOCKER-USER -p tcp --dport 53 -d 8.8.4.4 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.8.8 -j DROP
iptables -I OUTPUT -p udp --dport 53 -d 8.8.4.4 -j DROP
iptables -I OUTPUT -p tcp --dport 53 -d 8.8.4.4 -j DROP

echo "done" > /tmp/background-done
