param ( 
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl
)

# Function to simulate a numerical progress bar
function Show-ProgressBar {
    param (
        [int]$DelaySeconds,
        [string]$TaskName
    )
    Write-Host "$TaskName"
    for ($i = 1; $i -le $DelaySeconds; $i++) {
        Write-Host -NoNewline "`rLoading: $i / $DelaySeconds seconds"
        Start-Sleep -Seconds 1
    }
    Write-Host "`nLoading complete!"
}

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

# Comments for CPU and RAM Usage
$cpuCommentOptions = @(
    "CPU's maxed out - running a marathon with no water breaks",
    "CPU is being stretched thin - every app is demanding attention",
    "CPU is handling tasks efficiently - no major bottlenecks here"
)
$ramCommentOptions = @(
    "RAM is overloaded - applications are crawling",
    "RAM is tight - Chrome and your CRM are wrestling for scraps",
    "RAM looks healthy - system performance is stable"
)

# Randomly Select Comments
$cpuComment = $cpuCommentOptions | Get-Random
$ramComment = $ramCommentOptions | Get-Random

# Fetch and Normalize CPU Usage
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } | Sort-Object CPU -Descending | 
    Select-Object -First 5 -Property ProcessName, @{Name="CPU_Usage"; Expression={[math]::Round(($_.CPU / $logicalProcessors), 2)}}

# Fetch Top RAM Usage
$topRAM = Get-Process | Sort-Object PM -Descending | 
    Select-Object -First 5 -Property ProcessName, @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Add Relatable Comments to CPU & RAM
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser - hogging resources." }
    elseif ($process -match "explorer") { "File explorer - system navigation." }
    elseif ($process -match "Discord") { "Chat app - productivity or memes, you decide." }
    elseif ($process -match "MsMpEng") { "Antivirus - scanning for threats." }
    else { "Background task - using resources quietly." }
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
Your current specs are slowing things down. Here's what you need:
- **RAM:** $recommendedRAM
- **CPU:** $cpuUpgrade

Search for **prebuilt desktops** with these specs on Amazon or Best Buy:
- **Search Phrase:** "Budget Desktop PC 16GB RAM Intel i5 10th Gen or Ryzen 5 under $500"
"@

# Send Report to Discord
$msg = @{ content = $report } | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}

# Debug File Creation Check
Show-ProgressBar -DelaySeconds 10 -TaskName "Ensuring report debug file is created..."

# Write Debug Log and Open
$debugPath = "$env:TEMP\system_report_debug.txt"
$report | Out-File -FilePath $debugPath -Encoding UTF8

if (Test-Path $debugPath) {
    Write-Host "Debug file created successfully! Opening..."
    Start-Process notepad $debugPath
} else {
    Write-Host "Failed to create debug file. Please check script execution." -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
