#!/usr/bin/env bash
# Диагностика на VPS. Запускать по SSH.
set -euo pipefail

TARGET_HOME="${TARGET_HOME:-10.10.0.2}"
REPORT="/tmp/nas-speed-check-vps.txt"

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$REPORT"
}

: > "$REPORT"
log "=== VPS NAS speed check ==="
log "hostname=$(hostname)  ip=$(hostname -I | awk '{print $1}')"

log $'\n--- sysctl ---'
sysctl net.ipv4.ip_forward net.core.rmem_max net.core.wmem_max net.ipv4.tcp_congestion_control 2>/dev/null | tee -a "$REPORT" || true

log $'\n--- wg / ip ---'
(command -v wg >/dev/null && wg show) | tee -a "$REPORT" || log "wireguard tools not installed"
ip -br addr | tee -a "$REPORT"
ip route | tee -a "$REPORT"

log $'\n--- ping home peer ---'
ping -c 10 -W 2 "$TARGET_HOME" | tee -a "$REPORT" || log "home peer $TARGET_HOME unreachable"

log $'\n--- listening file services ---'
ss -lntup | grep -E ':80|:443|:445|:139|:2049|:5005|:51821|:51820|:5201' | tee -a "$REPORT" || true

log $'\n--- caddy ---'
if command -v caddy >/dev/null; then
  caddy version | tee -a "$REPORT"
  systemctl is-active caddy | tee -a "$REPORT" || true
else
  log "caddy not in PATH"
fi

log $'\n--- iperf3 server ---'
log "Install if needed:  apt-get install -y iperf3"
log "Listen:             iperf3 -s -p 5201"
log "From Windows:       iperf3 -c files.zethixhome.ru -p 5201 -t 20 -P 4"
log "To home NAS:        iperf3 -c $TARGET_HOME -p 5201 -t 20"

log $'\nReport saved: '"$REPORT"
