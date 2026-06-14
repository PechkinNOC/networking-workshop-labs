## Рішення

**Причина:** Java має власний DNS resolver — не читає `/etc/gai.conf`.
gai.conf впливає на glibc `getaddrinfo()`. Java JVM використовує власний network stack.

**Рішення:**

```bash
# Зупинити поточний Java процес
kill $(pgrep java)

# Перезапустити з JVM флагом
java -Djava.net.preferIPv4Stack=true -cp /opt TestDns
```

**Ключовий висновок:** gai.conf — не срібна куля. Різні runtime (JVM, Go, Python) мають різні DNS стеки.
Завжди перевіряй чи конкретний runtime використовує glibc або власну реалізацію.
