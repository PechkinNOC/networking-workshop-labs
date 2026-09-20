## Рішення

**Причина:** conntrack timeout для TCP ESTABLISHED = 10 секунд (замість дефолтних ~5 годин).
Сервер мовчить 15 секунд - довше за timeout, тому conntrack "забуває" з'єднання.
Наступний пакет від сервера приходить посеред потоку без запису в conntrack → INVALID → DROP.
RST від TCP stack теж → INVALID → DROP.
Обидва боки зависають мовчки.

> У цьому середовищі ще вимкнено `nf_conntrack_tcp_loose` (`cat /proc/sys/net/netfilter/nf_conntrack_tcp_loose` покаже 0).
> З дефолтним `1` conntrack підхопив би з'єднання посеред потоку і воно вижило б. Так зазвичай і буває на хостах
> без NAT. З NAT або strict-режимом (звичайна річ на firewall/gateway) - з'єднання гине.

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

---

## Зв'язок з DDoS

Схожа тиша виникає під час **conntrack table exhaustion** (наприклад, SYN flood):

1. Атакуючий шле масово SYN-пакети → кожен створює запис у conntrack
2. Таблиця заповнюється (`nf_conntrack_count` → `nf_conntrack_max`)
3. Ядро пише в `dmesg`: `nf_conntrack: table full, dropping packet` - нові з'єднання (включно з легітимними) мовчки зникають
4. Типова реакція адміна - **скоротити timeout'и**, щоб швидше звільняти записи
5. Але тоді починають вмирати легітимні idle-з'єднання - рівно як у цьому сценарії

```bash
# Заповненість таблиці - головний індикатор
cat /proc/sys/net/netfilter/nf_conntrack_count   # поточне
cat /proc/sys/net/netfilter/nf_conntrack_max     # максимум
dmesg | grep 'table full'

# Кількість half-open з'єднань - індикатор SYN flood
conntrack -L | grep SYN_RECV | wc -l

# Звідки йде flood
conntrack -L | grep SYN_RECV | awk '{print $5}' | cut -d= -f2 \
  | sort | uniq -c | sort -rn | head
```

❓ **Бонус-питання:** як відрізнити неправильний timeout від реальної атаки не дивлячись в логи?

<details>
<summary>Відповідь</summary>

`conntrack -L | grep SYN_RECV | wc -l`

Якщо **тисячі** - атака. Якщо **одиниці** - misconfiguration або нормальний трафік.
Також: `nf_conntrack_count` близький до `nf_conntrack_max` - ознака exhaustion під навантаженням.
</details>
