## Рішення

**Причина:** Асиметричний роутинг → conntrack INVALID → iptables DROP.

SYN від клієнта прийшов через eth1. Але `ip route get 10.10.20.100` показує eth0.
conntrack не може відстежити з'єднання — пакети потрапляють в INVALID.

**Рішення — policy routing:**

```bash
ip rule add from 10.10.20.0/24 table 100
ip route add default via <eth1_gw> table 100
```

Тепер відповідь іде через eth1. conntrack бачить повний цикл → ESTABLISHED.

**Persistent:** налаштувати через netplan або `/etc/network/interfaces`.
