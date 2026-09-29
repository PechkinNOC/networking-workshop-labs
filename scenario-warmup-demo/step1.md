## Стандартний checklist

**Кроки demo:**

**1. Мережева зв'язність**

```bash
ping -c2 api.internal
```

> Відповідає - L3 зв'язність є

**2. DNS**

```bash
nslookup api.internal
dig api.internal
```

> Впевнено показує `1.2.3.4`

**3. Детальніше - curl -v**

```bash
curl -v http://api.internal:8080/
```

> Реально йде на `5.6.7.8`, не на `1.2.3.4`

**4. Хто слухає**

```bash
ss -tlnp
```

> На `1.2.3.4:8080` щось слухає, на `5.6.7.8` - нічого

**5. Що бачить застосунок насправді**

```bash
getent hosts api.internal
cat /etc/hosts
```

> `getent` показує те саме, що curl. Розбіжність із DNS - застарілий запис у `/etc/hosts`
