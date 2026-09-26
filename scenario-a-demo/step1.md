## Стандартний checklist

**Кроки demo:**

```bash
# 1. Симптом з боку клієнта
from-client ping -c3 10.10.20.1
from-client curl -v -m 5 http://10.10.20.1:8080

# 2. Сервіс живий? На якій адресі слухає?
ss -tlnp | grep 8080

# 3. Firewall - чи є що дропати?
iptables -L INPUT -n -v

# 4. Запити доходять? Дивимось на eth1
tcpdump -ni eth1 icmp        # в іншому вікні: from-client ping -c3 10.10.20.1

# 5. А куди йдуть відповіді? Дивимось на основний інтерфейс
tcpdump -ni enp1s0 icmp

# 6. Який маршрут до клієнта?
ip route get 10.10.30.100

# 7. Рішення - policy routing
ip route add 10.10.20.0/24 dev eth1 table 100
ip route add default via 10.10.20.100 dev eth1 table 100
ip rule add from 10.10.20.1 table 100
```
