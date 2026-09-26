## Стандартний checklist

**Кроки demo:**

**1. Симптом**

```bash
from-client ping -c3 10.10.50.2
```

```bash
from-client curl -I http://10.10.50.2:8080/
```

```bash
from-client curl -v -m 8 http://10.10.50.2:8080/
```

> Ping ок, HEAD ок, звичайний GET висить після заголовків - тіло не приходить

**2. Знайти поріг розміру**

```bash
from-client ping -M do -c1 -s 1372 10.10.50.2
from-client ping -M do -c1 -s 1400 10.10.50.2
```

> `-M do` забороняє фрагментацію. Десь між цими розмірами пакет перестає проходити - саме тут пролягає межа

**3. Що на рівні пакетів**

```bash
tcpdump -ni cli0 -n
```

> В іншому вікні повторити `from-client curl -m 8 http://10.10.50.2:8080/`. Видно: сервер повторно шле той самий великий сегмент - і жодної ICMP-відповіді ніколи не приходить

**4. Чи щось дропається на роутері**

```bash
iptables -L OUTPUT -n -v
```

> Лічильник на правилі з ICMP росте з кожною спробою

**5. Рішення**

```bash
# Варіант 1 - прибрати блокування (корінна причина)
iptables -D OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP

# Варіант 2 - MSS clamping (працює навіть якщо ICMP заблокований деінде на шляху)
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```
