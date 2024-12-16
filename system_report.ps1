param (
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl
)

# Collect System Metrics
$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)

# Top Processes by CPU
$topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property ProcessName, CPU

# Top Processes by RAM
$topRAM = Get-Process | Sort-Object PM -Descending | Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Build the Report
$report = @"
**System Resource Report:**

**CPU Usage:** $cpuLoad%  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB  

**Top 5 CPU Usage:**
$($topCPU | Format-Table -AutoSize | Out-String)

**Top 5 RAM Usage:**
$($topRAM | Format-Table -AutoSize | Out-String)
"@

# Convert Report to JSON
$msg = @{
    content = $report
} | ConvertTo-Json -Compress

# Send to Discord Webhook
try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}
