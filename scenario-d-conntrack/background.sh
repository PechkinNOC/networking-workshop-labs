#!/bin/bash

# Short conntrack timeout — connection entry disappears after 10 seconds of "idle"
# (idle from conntrack's perspective: no packets that reset the timer)
echo 10 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established

# Drop INVALID packets — without this rule TCP would eventually recover via retransmit+RST
# With it: RST itself arrives as INVALID and is also dropped → silent hang
iptables -I INPUT -m conntrack --ctstate INVALID -j DROP

# Server: sends a timestamped message every 2 seconds
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
    time.sleep(2)
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
