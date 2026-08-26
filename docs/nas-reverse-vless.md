# 502 после смены IP VPS: как починить nas-bridge по SSH

Короткий вывод: Caddy и DNS уже смотрят на **62.60.152.45**. Ломается не сайт, а **домашний VLESS-клиент `nas-bridge`**: он всё ещё стучится на старый IP `62.60.186.230`. Пока мост не поднят, на VPS нет исходящего `nas-reverse-out`, и Caddy отдаёт 502.

Править нужно **`address` у outbound на роутере**, лучше на домен `nas.zethixhome.ru` (не `nas.zehixhome.ru`). Reality `serverName` не трогать.

## Почему так

```text
браузер
  → https://nas.zethixhome.ru / files.zethixhome.ru
  → Caddy :443  (живой, Basic Auth)
  → 127.0.0.1:15001 / :15005   (dokodemo-door Xray)
  → outboundTag nas-reverse-out   ← появляется ТОЛЬКО когда дом подключён
        ↑
домашний роутер: reverse.bridges tag=nas-bridge
  → VLESS + Reality :23630
  → address = ???   ← здесь сейчас старый IP
```

Проверено снаружи после смены IP:

| Что | Состояние |
|---|---|
| DNS `nas.zethixhome.ru` и `files.zethixhome.ru` | `62.60.152.45` |
| Caddy :443 | отвечает, сертификат Let's Encrypt на `nas.zethixhome.ru` |
| Reality inbound `:23630` на новом IP | **открыт** |
| RustDesk `:21115–21118` | на самом VPS, туннель NAS не нужен — поэтому он живой |
| Старый IP `62.60.186.230` | не пингуется |
| Лог Xray | `non existing outTag: nas-reverse-out` = моста нет |

VPN «VLESS Zethix» — это **другой** outbound (интернет). Он уже ходит на новый адрес. `nas-bridge` — отдельный клиент reverse-туннеля, его IP часто забывают.

WireGuard дома нет и не нужен для этой починки.

## 1. SSH на роутер

Обычный Keenetic/OpenWrt:

```bash
ssh admin@192.168.1.1
# или
ssh root@192.168.1.1
```

Дальше все команды **на роутере**.

## 2. Найти конфиг nas-bridge

```sh
grep -RIn --exclude-dir=proc --exclude-dir=sys \
  'nas-bridge\|nas-reverse\|23630\|62.60.186.230' \
  /opt/etc /etc /usr/local/etc /opt/etc/xray /opt/etc/xray/configs \
  2>/dev/null | head -80
```

Типичные места:

| Система | Файлы |
|---|---|
| Keenetic + XKeen | `/opt/etc/xray/configs/04_outbounds.json`, `05_reverse.json`, иногда один `config.json` |
| OpenWrt / Passwall | `/etc/xray/config.json`, `/usr/share/xray/` |
| sing-box | `/etc/sing-box/config.json`, `/opt/etc/sing-box/` |

Нужен outbound с портом **23630** (или тегом вроде `vps` / `portal` / `interconn`), на который routing кидает трафик с `inboundTag: nas-bridge` и доменом моста.

Выглядит примерно так:

```json
{
  "tag": "vps-nas",
  "protocol": "vless",
  "settings": {
    "vnext": [
      {
        "address": "62.60.186.230",
        "port": 23630,
        "users": [{ "id": "…", "encryption": "none", "flow": "xtls-rprx-vision" }]
      }
    ]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "serverName": "www.cloudflare.com",
      "publicKey": "…",
      "shortId": "…"
    }
  }
}
```

## 3. Что менять, а что нельзя

Меняйте **только TCP-адрес сервера**:

```json
"address": "nas.zethixhome.ru"
```

Домен уже резолвится в `62.60.152.45`. Следующая смена IP VPS потребует только правки DNS A-записи, не SSH на роутер.

Не используйте опечатку `nas.zehixhome.ru` — такого имени нет.

**Не меняйте** Reality-поля:

- `serverName` / `serverNames` — это маскировка TLS (часто microsoft/cloudflare/google), не ваш NAS
- `publicKey`, `shortId`, `spiderX`, UUID, `flow`, порт `23630`

Если подставить `nas.zethixhome.ru` в `serverName`, Reality-хендшейк сломается, даже при верном IP.

Порт оставьте **23630**. На новом VPS он слушает.

## 4. Правка с бэкапом

Подставьте найденный файл вместо `$FILE`:

```sh
FILE=/opt/etc/xray/configs/04_outbounds.json
cp -a "$FILE" "$FILE.bak.$(date +%Y%m%d%H%M%S)"

# посмотреть, сколько раз встречается старый IP
grep -n '62.60.186.230\|23630\|nas-bridge\|serverName' "$FILE"
```

Точечная замена только адреса (не `serverName`):

```sh
# BusyBox sed на Keenetic обычно есть
sed -i 's/"address": *"62.60.186.230"/"address": "nas.zethixhome.ru"/' "$FILE"

# проверка
grep -n 'address\|23630\|serverName' "$FILE"
```

Если в том же файле старый IP ещё где-то нужен (редко) — правьте руками через `vi` / `nano`, только блок `vnext` у nas-моста.

JSON после правки должен остаться валидным: запятые на месте, кавычки парные.

## 5. Перезапуск Xray на роутере

Что сработает — зависит от прошивки, пробуйте сверху вниз:

```sh
xkeen -restart
# или
/opt/etc/init.d/S24xray restart
# или
/opt/etc/init.d/S99xray restart
# OpenWrt:
/etc/init.d/xray restart
# sing-box:
/etc/init.d/sing-box restart
```

## 6. Проверка, что мост живой

На **роутере**:

```sh
nslookup nas.zethixhome.ru
# → 62.60.152.45

# исходящее TCP на Reality
netstat -ntp 2>/dev/null | grep 23630
# или
ss -ntp | grep 23630
# нужно ESTABLISHED на 62.60.152.45:23630
```

Лог клиента (путь может отличаться):

```sh
tail -n 50 /opt/var/log/xray/error.log
logread | grep -iE 'xray|sing-box|nas-bridge' | tail
```

На **VPS**:

```sh
# ошибка non existing outTag: nas-reverse-out должна пропасть
journalctl -u xray -n 80 --no-pager
# или
journalctl -u x-ui -n 80 --no-pager
grep -RIn nas-reverse-out /usr/local/etc/xray /usr/local/x-ui 2>/dev/null | head
```

После подключения моста Caddy перестаёт отдавать 502: `https://nas.zethixhome.ru` снова Basic Auth / DSM, `https://files.zethixhome.ru` — WebDAV.

## 7. Если XKeen/панель перезаписывает JSON

На Keenetic с XKeen профиль иногда живёт не в ручном JSON, а в подписке. Тогда правка файла откатится при `xkeen -u`.

Ищите GUI/профиль с именем вроде `nas-bridge` / `Zethix` / порт 23630 и смените **сервер/address** там же на `nas.zethixhome.ru`. Тот outbound, которым вы ходите в интернет («VLESS Zethix»), не обязан совпадать с мостом — у них разные теги.

## 8. На VPS ничего менять не нужно

Inbound Reality `:23630` уже слушает новый IP. Caddy уже проксирует на `127.0.0.1:15001` и `:15005`. Тег `nas-reverse-out` Xray создаёт сам, когда bridge подключился. Пока домашний клиент молчит, тега нет — это нормально, а не «битый конфиг VPS».

## Чеклист

- [ ] `nslookup nas.zethixhome.ru` на роутере = `62.60.152.45`
- [ ] В outbound моста `"address": "nas.zethixhome.ru"`, порт `23630`
- [ ] `serverName` Reality **не** `nas.zethixhome.ru`
- [ ] Xray/XKeen перезапущен
- [ ] Есть `ESTABLISHED` на `:23630`
- [ ] На VPS больше нет `non existing outTag: nas-reverse-out`
- [ ] `https://nas.zethixhome.ru` не 502
