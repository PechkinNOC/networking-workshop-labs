## Діагностика

Дані зупинились. TCP показує ESTABLISHED. Що далі?

```bash
# Стан TCP з'єднання
ss -tnp | grep 9000

# conntrack — є запис? В якому стані?
conntrack -L | grep 9000

# Стежити за conntrack в реальному часі
watch -n1 'conntrack -L | grep 9000'

# Чи ростуть INVALID лічильники?
iptables -L -n -v

# Що відбувається на рівні пакетів?
tcpdump -i lo port 9000 -n
```

**Підказки (відкривати поступово):**

<details>
<summary>Підказка 1</summary>
conntrack відстежує з'єднання незалежно від TCP. Що показує conntrack -L для цього з'єднання?
</details>

<details>
<summary>Підказка 2</summary>
conntrack має власні таймаути для TCP станів. Що станеться якщо TCP з'єднання "мовчить" довше ніж conntrack timeout?
</details>

<details>
<summary>Підказка 3</summary>
Перевір /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established — яке значення?
</details>
