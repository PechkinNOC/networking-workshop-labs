## Рішення

**Причина:** conntrack timeout для TCP ESTABLISHED = 10 секунд (замість дефолтних ~5 годин).
Після 10 секунд без пакетів conntrack "забуває" з'єднання.
Наступний пакет від сервера → INVALID → DROP.
RST від TCP stack теж → INVALID → DROP.
Обидва боки зависають мовчки.

---

**Варіант 1 — збільшити timeout:**

```bash
echo 3600 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
```

Постійно через sysctl:
```bash
echo 'net.netfilter.nf_conntrack_tcp_timeout_established = 3600' \
  >> /etc/sysctl.d/99-conntrack.conf
sysctl -p /etc/sysctl.d/99-conntrack.conf
```

**Варіант 2 — TCP keepalive (правильніше):**

Keepalive probe кожні 5 секунд тримає conntrack entry живим і виявляє мертве з'єднання:

```python
import socket
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 5)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 2)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 3)
```

---

**Ключовий висновок:** conntrack і TCP — два незалежних механізми з різними таймаутами.
TCP вважає з'єднання живим доки є ACK. conntrack — доки бачить пакети в межах свого timeout.
Якщо вони не узгоджені: з'єднання "живе" для TCP але "мертве" для firewall.

Типові місця де це виникає в продакшені: idle DB connections, long-polling HTTP, gRPC, WebSocket, SSH через NAT.
