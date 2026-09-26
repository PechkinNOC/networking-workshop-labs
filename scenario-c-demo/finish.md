## Рішення

**Причина:** IPv6 default route є, але веде через сусіда (шлюз), якого фізично нема - "router used to exist, RA застарів" сценарій.
gai.conf (дефолтний) надає пріоритет IPv6 → AAAA запит → спроба з'єднання по IPv6 → ядро шле Neighbor Solicitation і чекає відповіді, якої не буде → кілька секунд таймауту Neighbor Discovery → тільки потім IPv4.
curl використовує Happy Eyeballs (паралельні запити) → не зачіпається.

**Рішення:**

```bash
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
```

IPv4-mapped адреси тепер мають вищий precedence → система спочатку пробує IPv4.

**Ключовий висновок:** curl і додаток можуть вести себе по-різному навіть для одного і того ж URL.
tcpdump на port 53 — перший крок при підозрі на DNS latency.
