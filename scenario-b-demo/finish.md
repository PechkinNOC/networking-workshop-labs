## Рішення

**Причина:** Docker побачив `127.0.0.53` в `/etc/resolv.conf` — loopback, недоступний з контейнера.
Fallback: Docker прописав `nameserver 8.8.8.8`. Але 8.8.8.8 заблокований egress правилами.

**Рішення:**

```bash
# Перевірити IP docker0
ip addr show docker0

# Запустити контейнер з DNS = docker0 IP
docker run --dns 172.17.0.1 alpine nslookup google.com

# Щоб для всіх контейнерів:
# /etc/docker/daemon.json: { "dns": ["172.17.0.1"] }
```

**Ключовий висновок:** Будь-який `127.x.x.x` — loopback namespace хоста. Контейнер ніколи його не побачить.
