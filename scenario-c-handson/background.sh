#!/bin/bash

# Remove any IPv6 default route
ip -6 route del default 2>/dev/null || true

# gai.conf ALREADY FIXED — Python will be fast
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf

# Install Java
apt-get update -q 2>/dev/null
apt-get install -y -q default-jre 2>/dev/null

# Create Java test client (no -Djava.net.preferIPv4Stack=true — this is the bug)
cat > /opt/TestDns.java << 'JEOF'
import java.net.*;
public class TestDns {
  public static void main(String[] a) throws Exception {
    System.out.println("Starting Java DNS test loop... (Ctrl+C to stop)");
    while (true) {
      long t = System.currentTimeMillis();
      try {
        new URL("https://example.com").openConnection().connect();
        System.out.println("took: " + (System.currentTimeMillis() - t) + "ms");
      } catch (Exception e) {
        System.out.println("error after " + (System.currentTimeMillis() - t) + "ms: " + e.getMessage());
      }
      Thread.sleep(3000);
    }
  }
}
JEOF

# Compile
javac /opt/TestDns.java -d /opt 2>/tmp/javac.log

# Start Java process in background (participants will observe its slowness)
java -cp /opt TestDns &>/tmp/javadns.log &

echo "done" > /tmp/background-done
