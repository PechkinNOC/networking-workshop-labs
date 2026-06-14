#!/bin/bash

# Ensure IPv6 is available on the interface (link-local auto-configures)
# Remove any IPv6 default route to create the "no route" condition
ip -6 route del default 2>/dev/null || true

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
