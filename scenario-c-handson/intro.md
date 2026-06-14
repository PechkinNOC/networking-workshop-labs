## Сценарій C — Hands-on

gai.conf вже виправлений. Python додаток — швидкий (~0.3 секунди).
Але є Java сервіс який все одно показує затримку ~2 секунди на запит.

**Симптом:** Java процес повільний, хоча gai.conf виглядає правильно.

---

Перевірка Java процесу (логи оновлюються в реальному часі):

```
tail -f /tmp/javadns.log
```

Порівняння з Python:

```
python3 -c "import urllib.request, time; t=time.time(); urllib.request.urlopen('https://example.com'); print(f'{time.time()-t:.2f}s')"
```

> Середовище налаштовується автоматично (~90 секунд після старту, встановлюється Java).
