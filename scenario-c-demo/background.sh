#!/bin/bash

# Ensure IPv6 is available on the interface (link-local auto-configures).
#
# Getting the actual multi-second delay right took two failed attempts:
#  - no route at all -> kernel returns ENETUNREACH synchronously, instant
#    IPv4 fallback (confirmed live: testapp.py answered in ~0.05-0.11s).
#  - "ip route add blackhole default" -> also instant (EINVAL) - Linux's
#    blackhole/unreachable/prohibit route types are all local, synchronous
#    decisions; no packet ever actually leaves the machine.
# What actually produces a real, multi-second hang: a default route that
# LOOKS valid but points at a link-local neighbor that will never answer
# Neighbor Discovery. The kernel really sends NS packets and waits for the
# NDP resolution to time out before giving up - confirmed live in an
# isolated netns: ~3s before "No route to host". This is also what a real
# "router used to exist, RA is stale" incident looks like.
PRIMARY_IFACE=$(ip -4 route show default | awk '/default/ {print $5; exit}')
ip -6 route del default 2>/dev/null || true
if [ -n "$PRIMARY_IFACE" ]; then
    ip -6 route add default via fe80::dead:beef dev "$PRIMARY_IFACE" 2>/dev/null || true
fi

# Leave gai.conf at default (prefers IPv6 — ::ffff:0:0/96 has low precedence)
# Default gai.conf: IPv6 addresses preferred over IPv4-mapped addresses

# Create the Python test app that demonstrates the latency
cat > /opt/testapp.py << 'PYEOF'
import urllib.request
import time

print("Starting request loop... (Ctrl+C to stop)")
while True:
    t = time.time()
    try:
        urllib.request.urlopen('https://example.com', timeout=10)
        print(f"Request took {time.time()-t:.2f}s")
    except Exception as e:
        print(f"Error after {time.time()-t:.2f}s: {e}")
    time.sleep(3)
PYEOF

echo "done" > /tmp/background-done
