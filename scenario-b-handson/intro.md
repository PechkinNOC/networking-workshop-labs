## Сценарій B — Hands-on

Та сама проблема що в demo: DNS не працює всередині контейнера.
Але конфігурація відрізняється в двох місцях — рішення з demo не спрацює напряму.

**Симптом:** `docker exec webserver curl https://google.com` зависає на DNS resolution.

---

Перевірка стану контейнера:

```
docker exec webserver curl -v https://google.com
docker exec webserver cat /etc/resolv.conf
docker exec webserver nslookup google.com
```

> Середовище налаштовується автоматично (~60 секунд після старту, встановлюється unbound).
