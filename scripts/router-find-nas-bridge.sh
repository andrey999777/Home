#!/bin/sh
# Запускать по SSH на домашнем роутере.
# Ищет конфиг VLESS reverse-моста nas-bridge / порт 23630 / старый IP VPS.

echo "=== host ==="
uname -a 2>/dev/null || true
hostname 2>/dev/null || true

echo
echo "=== search configs ==="
grep -RIn --exclude-dir=proc --exclude-dir=sys --exclude-dir=dev \
  'nas-bridge\|nas-reverse\|23630\|62.60.186.230\|62.60.152.45' \
  /opt/etc /etc /usr/local/etc /opt/etc/xray /opt/etc/xray/configs \
  /etc/xray /usr/share/xray /etc/sing-box /opt/etc/sing-box \
  2>/dev/null | head -120

echo
echo "=== dns nas.zethixhome.ru ==="
nslookup nas.zethixhome.ru 2>/dev/null || true
busybox nslookup nas.zethixhome.ru 2>/dev/null || true

echo
echo "=== tcp to Reality 23630 ==="
netstat -ntp 2>/dev/null | grep 23630 || true
ss -ntp 2>/dev/null | grep 23630 || true

echo
echo "Дальше: в найденном outbound с портом 23630 поставьте"
echo '  "address": "nas.zethixhome.ru"'
echo "Не трогайте realitySettings.serverName. Затем перезапустите xray/xkeen."
