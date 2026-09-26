## Стандартний checklist

**Кроки demo:**

**1. Відтворити і порівняти**

```bash
time curl https://example.com
```

```bash
python3 /opt/testapp.py
```

> В окремому терміналі

**2. DNS трафік**

```bash
tcpdump -i any port 53 -n
```

**3. IPv6 стан**

```bash
ip addr | grep inet6
ip -6 route show
```

**4. Рішення**

```bash
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
```

```bash
python3 /opt/testapp.py
```

> Перевірити, що стало швидко
