## Знайди і виправ проблему

DNS в контейнері не працює. Два відхилення від demo.

Перевір стан контейнера:

```bash
docker exec webserver cat /etc/resolv.conf
docker exec webserver nslookup google.com
```

Перевір хост:

```bash
cat /etc/resolv.conf
ip addr show docker0
```

> Підказки відкриваються поступово в чаті від ведучого

**Ціль:** `nslookup google.com` з контейнера повертає відповідь.
