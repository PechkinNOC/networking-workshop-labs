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

# Leave gai.conf at default.
#
# Relying on glibc's own getaddrinfo(AF_UNSPEC) sort order turned out to be
# unreliable in practice: confirmed live, even with the broken route above,
# getaddrinfo put the IPv4 candidates FIRST and 'ip -6 neigh show' stayed
# completely empty afterwards - Python never even tried IPv6. Modern glibc
# implements RFC 6724 Rule 1 ("avoid unusable destinations") and apparently
# detects the dead route well enough to skip it in the sort, defeating the
# whole demo before it starts.
#
# So testapp.py controls the attempt order itself instead of trusting
# getaddrinfo(AF_UNSPEC): it explicitly tries AF_INET6 first (a real
# connect(), not filtered by glibc's own heuristics - this DOES hit the
# NDP timeout above), then falls back to AF_INET. To keep the gai.conf
# "fix" meaningful, it reads the same precedence line the fix appends and
# flips its own order accordingly - so the fix still does something, just
# via the app reading the file instead of glibc's sort.

cat > /opt/testapp.py << 'PYEOF'
import socket
import ssl
import time

HOST = 'example.com'
PORT = 443


def prefer_ipv4():
    # Mirrors the one gai.conf knob this demo teaches - not a full RFC 6724
    # implementation, just enough to make the "fix" command do something.
    try:
        with open('/etc/gai.conf') as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 3 and parts[0] == 'precedence' and parts[1] == '::ffff:0:0/96':
                    return int(parts[2]) >= 40
    except OSError:
        pass
    return False


def connect():
    families = (socket.AF_INET, socket.AF_INET6) if prefer_ipv4() else (socket.AF_INET6, socket.AF_INET)
    last_err = OSError('no address family produced a connection')
    for family in families:
        try:
            addrs = socket.getaddrinfo(HOST, PORT, family, socket.SOCK_STREAM)
        except socket.gaierror as e:
            last_err = e
            continue
        for fam, socktype, proto, _, sockaddr in addrs:
            try:
                s = socket.socket(fam, socktype, proto)
                s.settimeout(5)
                s.connect(sockaddr)
                return s
            except OSError as e:
                last_err = e
    raise last_err


print("Starting request loop... (Ctrl+C to stop)")
ctx = ssl.create_default_context()
while True:
    t = time.time()
    try:
        raw = connect()
        with ctx.wrap_socket(raw, server_hostname=HOST) as tls:
            tls.sendall(f"GET / HTTP/1.1\r\nHost: {HOST}\r\nConnection: close\r\n\r\n".encode())
            tls.recv(1)
        print(f"Request took {time.time()-t:.2f}s")
    except Exception as e:
        print(f"Error after {time.time()-t:.2f}s: {e}")
    time.sleep(3)
PYEOF

echo "done" > /tmp/background-done
