#!/bin/bash

# Ubuntu 24.04's needrestart apt hook can prompt interactively after any
# package install ("which services to restart?") and hang forever with no
# TTY attached - confirmed live on scenario B: apt-get install sat blocked
# for 50+ minutes with needrestart/dpkg-status children still running.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# conntrack userspace tool (not in the base image) and the kernel module
apt-get install -y -q conntrack 2>/dev/null
modprobe nf_conntrack 2>/dev/null

# Short conntrack timeout - the entry disappears after 10 seconds without packets
echo 10 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established

# Strict TCP tracking: a mid-stream packet with no conntrack entry is INVALID.
# With the default (tcp_loose=1) conntrack would silently re-create the entry
# and the connection would survive - as it does on most non-NAT hosts.
echo 0 > /proc/sys/net/netfilter/nf_conntrack_tcp_loose

# Drop INVALID packets - without this rule TCP would eventually recover via retransmit+RST
# With it: RST itself arrives as INVALID and is also dropped -> silent hang
iptables -I INPUT -m conntrack --ctstate INVALID -j DROP

# Server: sends a timestamped message every 15 seconds (idle longer than the 10s conntrack timeout)
cat > /opt/server.py << 'EOF'
import socket, time

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', 9000))
srv.listen(1)
print("Server listening on 127.0.0.1:9000 ...")
conn, addr = srv.accept()
print(f"Client connected: {addr}")
i = 0
while True:
    msg = f"[{time.strftime('%H:%M:%S')}] message #{i}\n"
    try:
        conn.sendall(msg.encode())
        print(f"Sent: {msg.strip()}")
    except Exception as e:
        print(f"Send failed: {e}")
        break
    i += 1
    time.sleep(15)
EOF

# Client: receives and prints with timestamps
cat > /opt/client.py << 'EOF'
import socket, time

s = socket.socket()
s.connect(('127.0.0.1', 9000))
print(f"[{time.strftime('%H:%M:%S')}] Connected to server. Receiving...")
while True:
    data = s.recv(1024)
    if not data:
        print(f"[{time.strftime('%H:%M:%S')}] Connection closed by server")
        break
    print(f"[{time.strftime('%H:%M:%S')}] Received: {data.decode().strip()}")
EOF

echo "done" > /tmp/background-done
