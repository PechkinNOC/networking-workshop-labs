## Знайди і виправ проблему

```bash
dig db1.test
unbound-host db1.test
unbound-host -r db1.test
```

`dig` показує правильну адресу. `unbound-host` - ні, навіть з `-r`.

<details>
<summary>Підказка 1</summary>
`unbound-host` за замовчуванням не читає `/etc/resolv.conf` взагалі - робить власну незалежну резолюцію. `-r` мав би це виправити, вказавши йому "форвардь туди, куди й система". Але не виправляє. Отже, справа не тільки в тому, куди йде запит.
</details>

<details>
<summary>Підказка 2</summary>
`unbound-host` лінкується на `libunbound` - той самий код, що й daemon `unbound`. Чи є в `unbound` щось вбудоване, що спеціально обробляє певні доменні імена ще до форвардингу? Погугли "unbound default local-zone special-use domains".
</details>

<details>
<summary>Підказка 3</summary>
`man unbound-host` -> опція `-C <configfile>` - завантажує `unbound.conf`-подібний конфіг. Що там можна прописати для зони `test.`, щоб прибрати вбудовану обробку?
</details>

**Ціль:** `unbound-host -C <твій конфіг> db1.test` повертає `10.77.0.5`.
