## Стандартний checklist

**Кроки demo:**

**1. Хост живий?**

```bash
ping 8.8.8.8
dig google.com
```

**2. Всередині контейнера**

```bash
docker exec webserver curl -v https://google.com
docker exec webserver cat /etc/resolv.conf
```

**3. Чому 8.8.8.8 не доступний**

```bash
docker exec webserver nslookup google.com 8.8.8.8
iptables -L DOCKER-USER -n -v
```

> NB: трафік контейнера йде через FORWARD/NAT, не через OUTPUT

**4. Що на хості**

```bash
cat /etc/resolv.conf
docker exec webserver ping 127.0.0.53
```

**5. Рішення**

```bash
ip addr show docker0
```

> `docker0` покаже дві адреси - шлюз і наш стаб-резолвер (додано поверх). Бере останню:

```bash
docker run --dns $(ip addr show docker0 | awk '/inet /{print $2}' | tail -1 | cut -d/ -f1) alpine nslookup google.com
```
