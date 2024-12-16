param ( 
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl
)

# Collect Current System Specs
$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)
$cpuName = (Get-CimInstance Win32_Processor).Name
$logicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

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

# Randomized Comments for CPU and RAM Usage
function Get-CPUComment($usage) {
    $comments = if ($usage -ge 90) {
        @(
            "CPU's maxed out – it's running a marathon with no water breaks.",
            "Heavy load – the processor is begging for mercy.",
            "CPU is redlining – every app is demanding attention.",
            "You're overworking the CPU – consider closing unnecessary apps.",
            "CPU is sweating – heavy multitasking detected."
        )
    } elseif ($usage -ge 50) {
        @(
            "CPU is working hard, but keeping its cool.",
            "Moderate load detected – multitasking is pushing the limits.",
            "CPU is focused, but things could slow down under heavy tasks.",
            "Processor is handling the workload, but room for improvement.",
            "CPU is clocked in and pulling overtime."
        )
    } else {
        @(
            "CPU load is light – plenty of headroom left.",
            "Processor is chilling – it’s coasting through tasks.",
            "CPU usage is low – the system is cruising along smoothly.",
            "Minimal load detected – CPU is idle and waiting.",
            "CPU is ready for action – it's barely breaking a sweat."
        )
    }
    return ($comments | Get-Random)
}

function Get-RAMComment($used, $total) {
    $usagePercent = 100 - ($used / $total * 100)
    $comments = if ($usagePercent -lt 25) {
        @("RAM's holding steady – no issues here.",
          "Plenty of free memory – multitasking won't hurt.",
          "RAM usage is light – this machine is ready for anything.")
    } elseif ($usagePercent -lt 50) {
        @("RAM is starting to work harder, but still manageable.",
          "Memory usage is moderate – heavy apps could push it.",
          "RAM is juggling tasks, but it’s handling them fine.")
    } else {
        @("RAM's at capacity – Chrome and CRM are hogging it all.",
          "Memory is maxed – tasks will slow down soon.",
          "RAM is sweating bullets – an upgrade is overdue.")
    }
    return ($comments | Get-Random)
}

# Fetch Top CPU Usage
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } | Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, @{Name="CPU_Usage"; Expression={[math]::Round(($_.CPU / $logicalProcessors), 2)}}

# Fetch Top RAM Usage
$topRAM = Get-Process | Sort-Object PM -Descending | 
    Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Add Relatable Comments to CPU & RAM Processes
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser - hogging resources like Jeff at a buffet." }
    elseif ($process -match "explorer") { "File explorer - Windows is crawling." }
    elseif ($process -match "Discord") { "Chat app - critical for meme distribution." }
    elseif ($process -match "MsMpEng") { "Antivirus - working harder than your excuses." }
    else { "Background task – freeloading on resources." }
}

# Format CPU Report
$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-ProcessComment $_.ProcessName)" }

# Format RAM Report
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $(Get-ProcessComment $_.ProcessName)" }

# Final Report Content
$report = @"
**System Resource Report:**

**CPU Name:** $cpuName  
**CPU Usage:** $cpuLoad% - $(Get-CPUComment $cpuLoad)  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB - $(Get-RAMComment $availableRAM $totalRAM)  

**Top 5 CPU Usage:**
$($cpuReport -join "`n")

**Top 5 RAM Usage:**
$($ramReport -join "`n")

**Recommended Upgrades (1.5x to 2x Better):**
Your current specs are slowing things down. Here's what you need:
- **RAM:** $recommendedRAM
- **CPU:** $cpuUpgrade

Search for **prebuilt desktops** with these specs on Amazon or Best Buy:
- **Search Phrase:** "Budget Desktop PC 32GB RAM Intel i5 12th Gen or Ryzen 5 under $500"
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
