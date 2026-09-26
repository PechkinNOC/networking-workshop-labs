## Діагностика

Дані зупинились. TCP показує ESTABLISHED. Що далі?

Стан TCP з'єднання:

```bash
ss -tnp | grep 9000
```

conntrack — є запис? В якому стані?

```bash
conntrack -L | grep 9000
```

Стежити за conntrack в реальному часі:

```bash
watch -n1 'conntrack -L | grep 9000'
```

Чи ростуть INVALID лічильники?

```bash
iptables -L -n -v
```

Що відбувається на рівні пакетів?

```bash
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
