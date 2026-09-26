## Стандартний checklist

Ведучий веде demo — стежи і відповідай на питання в чаті.

**Кроки demo:**

```bash
# 1. Відтворити і порівняти
time curl https://example.com
python3 /opt/testapp.py   # в окремому терміналі

# 2. DNS трафік
tcpdump -i any port 53 -n

# 3. IPv6 стан
ip addr | grep inet6
ip -6 route show

# 4. Рішення
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
python3 /opt/testapp.py   # перевірити що стало швидко
```
