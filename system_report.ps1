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
    $cpuComment = "System's about to combust - running harder than me trying to explain taxes to a rock."
} elseif ($cpuLoad -ge 50) {
    $cpuComment = "Moderate load - multitasking like a parent on a Tuesday: stressed but holding it together."
} else {
    $cpuComment = "Light load - casually vibing like a guy scrolling Twitter for the 8th time today."
}

# RAM Usage Comments
if ($availableRAM -lt ($totalRAM * 0.25)) {
    $ramComment = "Memory is shot - Chrome has officially declared war on your system."
} elseif ($availableRAM -lt ($totalRAM * 0.5)) {
    $ramComment = "RAM's tight - Windows is holding on by a thread while Chrome chews through everything."
} else {
    $ramComment = "Memory's fine - system's cruising, which is rare given how cheap these PCs are."
}

# Process Comments
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browsing - your CRM tasks are why the system wheezes louder than a 90s lawnmower." }
    elseif ($process -match "explorer") { "File explorer - Windows working overtime to let you open folders slower than dial-up." }
    elseif ($process -match "Discord") { "Chat apps - because you *need* to tell Jeff his joke sucked during peak hours." }
    elseif ($process -match "MsMpEng") { "Antivirus - fighting malware while your system fights for its life." }
    elseif ($process -match "SearchApp") { "Windows Search - finding your files slower than IT finding funds for upgrades." }
    else { "General Task - some background nonsense hogging resources like it pays rent." }
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
Since you're reading this, it means the PCs are donezo. Buy one of these:

- HP Pavilion Desktop - [Amazon - $449](https://www.amazon.com/dp/B08XYZ)  
- Lenovo IdeaCentre - [Best Buy - $499](https://www.bestbuy.com/site/lenovo-ideacentre/6414762.p)
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
