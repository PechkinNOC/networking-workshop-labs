#!/bin/bash

# Ubuntu 24.04's needrestart apt hook can prompt interactively after any
# package install ("which services to restart?") and hang forever with no
# TTY attached - confirmed live on scenario B: apt-get install sat blocked
# for 50+ minutes with needrestart/dpkg-status children still running.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Remove any IPv6 default route
ip -6 route del default 2>/dev/null || true

# gai.conf ALREADY FIXED — Python will be fast
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf

# Install Java. Needs the JDK, not just the JRE: default-jre has no javac,
# and the compile step right below would fail (confirmed by inspection -
# default-jre packages ship the runtime only, javac requires default-jdk).
apt-get update -q 2>/dev/null
apt-get install -y -q default-jdk 2>/dev/null

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
