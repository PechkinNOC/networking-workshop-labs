## Знайди чому Java все ще повільна

gai.conf виправлений, Python швидкий. Java — ні.

Перевір gai.conf:

```bash
cat /etc/gai.conf
```

Порівняй Python і Java:

```bash
python3 -c "import urllib.request, time; t=time.time(); urllib.request.urlopen('https://example.com'); print(f'{time.time()-t:.2f}s')"
```

```bash
tail -f /tmp/javadns.log
```

Перевір Java процес:

```bash
ps aux | grep java
```

> Підказки відкриваються поступово в чаті від ведучого

**Ціль:** Java процес показує ~0.3с замість ~2с.
