## Сценарій B — Demo

На хості все працює: `ping 8.8.8.8` є, `dig google.com` резолвиться.
Але всередині контейнера DNS не працює — ні зовнішні, ні внутрішні домени.

**Симптом:** `docker exec webserver curl https://google.com` зависає на DNS resolution.

---

Перевірка стану контейнера:

```
docker exec webserver curl -v https://google.com
docker exec webserver cat /etc/resolv.conf
docker exec webserver nslookup google.com
```

> Середовище налаштовується автоматично (~30 секунд після старту).
