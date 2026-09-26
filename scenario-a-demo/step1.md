## Стандартний checklist

**Кроки demo:**

**1. Симптом з боку клієнта**

```bash
from-client ping -c3 10.10.20.1
from-client curl -v -m 5 http://10.10.20.1:8080
```

**2. Сервіс живий? На якій адресі слухає?**

```bash
ss -tlnp | grep 8080
```

**3. Firewall - чи є що дропати?**

```bash
iptables -L INPUT -n -v
```

**4. Запити доходять? Дивимось на eth1**

```bash
tcpdump -ni eth1 icmp
```

> В іншому вікні: `from-client ping -c3 10.10.20.1`

**5. А куди йдуть відповіді? Дивимось на основний інтерфейс**

```bash
tcpdump -ni enp1s0 icmp
```

**6. Який маршрут до клієнта?**

```bash
ip route get 10.10.30.100
```

**7. Рішення - policy routing**

```bash
ip route add 10.10.20.0/24 dev eth1 table 100
ip route add default via 10.10.20.100 dev eth1 table 100
ip rule add from 10.10.20.1 table 100
```
