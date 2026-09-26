## Стандартний checklist

Ведучий веде demo — стежи і відповідай на питання в чаті.

**Кроки demo:**

```bash
# 1. Хост живий?
ping 8.8.8.8
dig google.com

# 2. Всередині контейнера
docker exec webserver curl -v https://google.com
docker exec webserver cat /etc/resolv.conf

# 3. Чому 8.8.8.8 не доступний
docker exec webserver nslookup google.com 8.8.8.8
iptables -L OUTPUT -n -v

# 4. Що на хості
cat /etc/resolv.conf
docker exec webserver ping 127.0.0.53

# 5. Рішення
ip addr show docker0
docker run --dns $(ip addr show docker0 | awk '/inet /{print $2}' | cut -d/ -f1) alpine nslookup google.com
```
