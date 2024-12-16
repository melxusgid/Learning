param (
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl
)

# Collect System Metrics
$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)

# CPU Usage Comments
if ($cpuLoad -ge 90) {
    $cpuComment = "System's about to combust - running harder than me trying to finish a task before 5 PM."
} elseif ($cpuLoad -ge 50) {
    $cpuComment = "Moderate load - multitasking like a parent on a Tuesday: stressed but holding it together."
} else {
    $cpuComment = "Light load - casually vibing like someone scrolling Twitter during lunch."
}

# RAM Usage Comments
if ($availableRAM -lt ($totalRAM * 0.25)) {
    $ramComment = "Memory is shot - Chrome has officially declared war on your PC."
} elseif ($availableRAM -lt ($totalRAM * 0.5)) {
    $ramComment = "RAM's tight - Windows is holding on by a thread while Chrome eats everything."
} else {
    $ramComment = "Memory's fine - surprisingly cruising along, unlike Jeff's work ethic."
}

# Process Comments Function
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser - hogging resources because your CRM insists on living in Chrome." }
    elseif ($process -match "explorer") { "File explorer - Windows dragging its feet so you can open a folder at snail speed." }
    elseif ($process -match "Discord") { "Chat app - because someone *really* needed to share a cat meme at 2 PM." }
    elseif ($process -match "MsMpEng") { "Antivirus - working overtime to keep your questionable downloads in check." }
    elseif ($process -match "SearchApp") { "Windows Search - struggling to find files faster than IT approving upgrades." }
    else { "General Task - some app freeloading resources like it owns the place." }
}

# Top Processes by CPU
$topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property ProcessName, @{Name="CPU_Usage"; Expression={[math]::Round($_.CPU, 2)}}

# Top Processes by RAM
$topRAM = Get-Process | Sort-Object PM -Descending | Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Build the Report
$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-ProcessComment $_.ProcessName)" }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $(Get-ProcessComment $_.ProcessName)" }

$report = @"
**System Resource Report:**

**CPU Usage:** $cpuLoad% - $cpuComment  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB - $ramComment  

**Top 5 CPU Usage:**
$($cpuReport -join "`n")

**Top 5 RAM Usage:**
$($ramReport -join "`n")

**Suggested Upgrade:**
Your systems are on life support. Upgrade to one of these prebuilt PCs for better performance:

- HP Pavilion Desktop - Amazon: https://www.amazon.com/dp/B08XYZ ($449)  
- Lenovo IdeaCentre - Best Buy: https://www.bestbuy.com/site/lenovo-ideacentre/6414762.p ($499)
"@

# Send to Discord
$msg = @{ content = $report } | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}
