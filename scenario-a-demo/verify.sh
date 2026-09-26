#!/bin/bash
# Passes once the client can actually reach the service - the acceptance
# criterion from intro.md/step1.md ("Клієнт має доступ до сервісу (http/ping)").
/usr/local/bin/from-client curl -sf -m 3 -o /dev/null http://10.10.20.1:8080 \
  && /usr/local/bin/from-client ping -c1 -W1 10.10.20.1 >/dev/null
