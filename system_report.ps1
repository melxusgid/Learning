param (
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl
)

# Collect Current System Specs
$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)
$cpuName = (Get-CimInstance Win32_Processor).Name

# Dynamic RAM Recommendation Logic
$recommendedRAM = if ($totalRAM -ge 16) {
    "Already sufficient RAM for current tasks."
} elseif ($totalRAM -lt 8) {
    "Upgrade to 16 GB RAM for smoother performance."
} elseif ($totalRAM -ge 8 -and $availableRAM -lt ($totalRAM * 0.25)) {
    "Upgrade to 16 GB or 32 GB RAM to handle your multitasking needs."
} else {
    "Upgrade to 16 GB RAM for optimal performance."
}

# CPU Recommendation Logic
$cpuUpgrade = if ($cpuName -match "i3|i5|Ryzen 3") {
    "Upgrade to Intel i5/i7 10th Gen or newer / AMD Ryzen 5 3600 for a 1.5x performance boost."
} elseif ($cpuName -match "i7|Ryzen 5|Ryzen 7") {
    "CPU is sufficient for most tasks - no upgrade needed unless under heavy load."
} else {
    "Already sufficient for tasks."
}

# Comments for CPU and RAM Usage
$cpuComment = if ($cpuLoad -ge 90) { "CPU's maxed out - it's like running a marathon while carrying groceries." }
elseif ($cpuLoad -ge 50) { "CPU's working hard - multitasking is stretching it thin." }
else { "CPU load is light - it's coasting through like a lazy intern." }

$ramComment = if ($availableRAM -lt ($totalRAM * 0.25)) { "RAM's maxed - Chrome and your CRM are wrestling for scraps." }
elseif ($availableRAM -lt ($totalRAM * 0.5)) { "RAM is under pressure - apps are crawling." }
else { "RAM usage looks manageable - but don't push your luck." }

# Top Processes (CPU & RAM)
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser - hogging resources like Jeff at a buffet." }
    elseif ($process -match "explorer") { "File explorer - Windows is limping along." }
    elseif ($process -match "Discord") { "Chat app - critical for sharing memes and workplace 'productivity'." }
    elseif ($process -match "MsMpEng") { "Antivirus - scanning harder than IT looking for your excuses." }
    else { "Background task - freeloading on system resources." }
}

$topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property ProcessName, @{Name="CPU_Usage"; Expression={[math]::Round($_.CPU, 2)}}
$topRAM = Get-Process | Sort-Object PM -Descending | Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-ProcessComment $_.ProcessName)" }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $(Get-ProcessComment $_.ProcessName)" }

# Build the Report
$report = @"
**System Resource Report:**

**CPU Name:** $cpuName  
**CPU Usage:** $cpuLoad% - $cpuComment  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB - $ramComment  

**Top 5 CPU Usage:**
$($cpuReport -join "`n")

**Top 5 RAM Usage:**
$($ramReport -join "`n")

**Recommended Upgrades (1.5x to 2x Better):**
Your current specs are slowing things down. Here's what you need:
- **RAM:** $recommendedRAM
- **CPU:** $cpuUpgrade

Search for **prebuilt desktops** with these specs on Amazon or Best Buy:
- **Search Phrase:** "Budget Desktop PC 16GB RAM Intel i5 10th Gen or Ryzen 5 under $500"
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
