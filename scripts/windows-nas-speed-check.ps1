# Диагностика узкого места NAS с удалённого Windows 10.
# Запускать в PowerShell от обычного пользователя.
# Пароли в вывод не попадают.

$ErrorActionPreference = "Continue"
$Target = "files.zethixhome.ru"
$OutDir = Join-Path $env:TEMP "nas-speed-check"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Log = Join-Path $OutDir "report.txt"

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $Log -Value $line
}

Write-Log "=== NAS speed check ==="
Write-Log "Host: $env:COMPUTERNAME"
Write-Log "Report: $Log"

Write-Log "`n--- TCP autotuning ---"
netsh interface tcp show global | Out-String | Tee-Object -FilePath $Log -Append | Out-Host

Write-Log "`n--- DNS ---"
Resolve-DnsName $Target | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $Log -Append | Out-Host

Write-Log "`n--- ping $Target ---"
ping -n 10 $Target | Out-String | Tee-Object -FilePath $Log -Append | Out-Host

Write-Log "`n--- tracert $Target (может занять минуту) ---"
tracert -d -w 1000 $Target | Out-String | Tee-Object -FilePath $Log -Append | Out-Host

Write-Log "`n--- netsh winsock / WebClient ---"
Get-Service WebClient | Format-List Status, StartType | Out-String | Tee-Object -FilePath $Log -Append | Out-Host

Write-Log "`n--- iperf3 ---"
Write-Log "На VPS заранее: iperf3 -s -p 5201"
Write-Log "Потом здесь:"
Write-Log "  iperf3 -c $Target -p 5201 -t 20 -P 1"
Write-Log "  iperf3 -c $Target -p 5201 -t 20 -P 4"
Write-Log "  iperf3 -c $Target -p 5201 -u -b 200M -t 20"

Write-Log "`n--- HTTPS GET без RaiDrive ---"
Write-Log "Подставьте путь к тестовому файлу 1+ ГБ:"
Write-Log "  curl.exe -L --http1.1 -u USER:PASS -o `$env:TEMP\nas-test.bin --write-out `"speed=%{speed_download} time=%{time_total}\n`" https://$Target/dl/test.bin"

Write-Log "`nГотово. Пришлите $Log (пароли из команд вырежьте)."
Write-Host "`nReport saved:" $Log
