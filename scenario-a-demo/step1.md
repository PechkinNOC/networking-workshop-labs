## Стандартний checklist

Фасилітатор веде demo — стежи і відповідай на питання в чаті.

**Кроки demo:**

```bash
# 1. L3 зв'язність
ip netns exec client ping 10.10.20.1

# 2. TCP — де зависає?
ip netns exec client curl -v http://10.10.20.1:8080

# 3. Firewall
iptables -L -n -v

# 4. conntrack стан
conntrack -L | grep 10.10.20

# 5. Маршрут для відповіді
ip route get 10.10.20.100

# 6. Рішення — policy routing
ip rule add from 10.10.20.0/24 table 100
ip route add default via $(ip route | awk '/default/{print $3}') table 100
```
