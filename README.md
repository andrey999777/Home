# Home

Документация домашней инфраструктуры.

## NAS через интернет

Туннель дом → VPS — это Xray reverse (`nas-bridge`, VLESS+Reality `:23630`), не WireGuard.
Публичный вход: Caddy → `127.0.0.1:15001` / `:15005` → `nas-reverse-out`.

- [502 после смены IP: починить nas-bridge по SSH](docs/nas-reverse-vless.md)
- [Почему WebDAV даёт 300 КБ/с](docs/nas-remote-speed.md)
