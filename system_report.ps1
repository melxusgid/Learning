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
    "Already sufficient RAM for current tasks"
} elseif ($totalRAM -lt 8) {
    "Upgrade to 16 GB RAM for smoother performance"
} elseif ($totalRAM -ge 8 -and $availableRAM -lt ($totalRAM * 0.25)) {
    "Upgrade to 16 GB or 32 GB RAM to handle your multitasking needs"
} else {
    "Upgrade to 16 GB RAM for optimal performance"
}

# CPU Recommendation Logic
$cpuUpgrade = if ($cpuName -match "i3|i5|Ryzen 3") {
    "Upgrade to Intel i5 or i7 10th Gen or newer or AMD Ryzen 5 3600 for better performance"
} elseif ($cpuName -match "i7|Ryzen 5|Ryzen 7") {
    "CPU is sufficient for most tasks no upgrade needed unless under heavy load"
} else {
    "Already sufficient for tasks"
}

# Random Comments for CPU Usage
$cpuCommentOptions = @(
    "CPU is maxed out running like a marathon with no breaks",
    "High load detected the processor is begging for relief",
    "CPU is overloaded every app is demanding resources",
    "CPU usage is heavy slowing everything down",
    "Processor is working overtime multitasking is hitting limits"
)

# Random Comments for RAM Usage
$ramCommentOptions = @(
    "RAM is fully used applications are struggling for space",
    "Memory pressure is high performance is dropping",
    "RAM usage is critical system is lagging behind",
    "Available memory is tight multitasking is suffering",
    "System memory is overworked close unnecessary tasks"
)

# Pick Random Comments
$cpuComment = $cpuCommentOptions | Get-Random
$ramComment = $ramCommentOptions | Get-Random

# Fetch and Normalize CPU Usage
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } | Sort-Object CPU -Descending | 
    Select-Object -First 5 -Property ProcessName, @{Name="CPU_Usage"; Expression={[math]::Round(($_.CPU / $logicalProcessors), 2)}}

# Fetch Top RAM Usage
$topRAM = Get-Process | Sort-Object PM -Descending | 
    Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Add Comments to Processes
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser hogging resources" }
    elseif ($process -match "explorer") { "File explorer struggling with load" }
    elseif ($process -match "Discord") { "Chat app consuming background resources" }
    elseif ($process -match "MsMpEng") { "Antivirus scanning hard for issues" }
    else { "Background task using system resources" }
}

# Format CPU Report
$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-ProcessComment $_.ProcessName)" }

# Format RAM Report
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
Your current specs are slowing things down. Here is what you need:
- **RAM:** $recommendedRAM
- **CPU:** $cpuUpgrade

Search for **prebuilt desktops** with these specs on Amazon or Best Buy:
- **Search Phrase:** "Budget Desktop PC 16GB RAM Intel i5 10th Gen or Ryzen 5 under 500 dollars"
"@

# Send Report to Discord
$msg = @{ content = $report } | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent" -ForegroundColor Green
}
catch {
    Write-Host "Failed to send the report $_" -ForegroundColor Red
}
