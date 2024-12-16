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
    Write-Host "`n$TaskName..." -ForegroundColor Cyan
    for ($i = 1; $i -le $DelaySeconds; $i++) {
        Write-Host -NoNewline "`rLoading: $i / $DelaySeconds seconds"
        Start-Sleep -Seconds 1
    }
    Write-Host "`r[Done] $TaskName completed!`n" -ForegroundColor Green
}

# Function to simulate a D6 dice roll
function Roll-Dice {
    return Get-Random -Minimum 1 -Maximum 7  # Rolls between 1 and 6
}

# Recommended Upgrade Suggestions
function Get-RecommendedUpgrades {
    # CPU Upgrade Suggestions
    $cpuUpgrade = switch -regex ($cpuName) {
        "i3|Ryzen 3" { "Upgrade to Intel i5 10th Gen or AMD Ryzen 5 3600 for better multitasking performance." }
        "i5|Ryzen 5" { "Upgrade to Intel i7 11th Gen or AMD Ryzen 7 for heavy workloads and faster processing." }
        "i7|Ryzen 7" { "Specs sufficient for most tasks. Upgrade if needed for intensive use." }
        default { "CPU is sufficient for general tasks. No immediate upgrade required." }
    }

    # RAM Upgrade Suggestions
    $ramUpgrade = if ($totalRAM -lt 8) {
        "Upgrade to 16GB RAM for smoother performance."
    } elseif ($totalRAM -lt 16) {
        "Upgrade to 32GB RAM for multitasking and heavier applications."
    } else {
        "RAM is sufficient for most workloads."
    }

    # Generate Search Query
    $searchQuery = if ($cpuUpgrade -notmatch "sufficient") {
        "Search for 'Desktop PC Intel i5 11th Gen or Ryzen 5 16GB RAM under $500'."
    } else {
        "No upgrade query needed. Your system is sufficient."
    }

    return @{
        CPU = $cpuUpgrade
        RAM = $ramUpgrade
        Search = $searchQuery
    }
}

# Step 1: Download and Confirm Script Execution
Show-ProgressBar -DelaySeconds 3 -TaskName "Downloading Script"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/melxusgid/Learning/main/system_report.ps1" `
    -OutFile "$env:TEMP\system_report.ps1"

if (-Not (Test-Path "$env:TEMP\system_report.ps1")) {
    Write-Host "Failed to download the script. Exiting." -ForegroundColor Red
    exit
}

# Step 2: Collect Current System Specs
Show-ProgressBar -DelaySeconds 3 -TaskName "Gathering System Information"

$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)
$cpuName = (Get-CimInstance Win32_Processor).Name
$logicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

# Dynamic Comment Pools for CPU and RAM Usage based on Thresholds
$cpuCommentsHigh = @(
    "CPU load is at its limit. Things might lag.",
    "Your CPU is under heavy load. Consider closing unused programs.",
    "Heavy CPU usage detected. This could impact performance.",
    "CPU working hard. Monitor tasks for unnecessary load.",
    "CPU is maxed out. Optimize your applications.",
    "CPU usage is critical. System stability may be affected."
)

$cpuCommentsMedium = @(
    "CPU load is moderate. Performing well.",
    "Your CPU is handling tasks efficiently.",
    "CPU multitasking without issues.",
    "Balanced CPU performance detected.",
    "CPU load is manageable. No major concerns.",
    "CPU usage is stable. Good system performance."
)

$cpuCommentsLow = @(
    "CPU is barely working. All systems are go.",
    "Your CPU is idling happily - no stress.",
    "Minimal CPU usage detected. System is relaxed.",
    "CPU is calm and steady.",
    "CPU usage is light. Plenty of headroom left.",
    "System idle. CPU performance is optimal."
)

$ramCommentsHigh = @(
    "RAM usage is high. System performance may suffer.",
    "Running out of memory. Close unnecessary tasks.",
    "High RAM usage detected. System may slow down.",
    "RAM is almost full. Consider upgrading.",
    "RAM overload detected. Optimize your applications.",
    "Low available RAM. Free up memory if possible."
)

$ramCommentsMedium = @(
    "RAM usage is moderate. Performing well.",
    "RAM is holding steady under pressure.",
    "Balanced RAM usage. No major concerns.",
    "RAM performance is stable for current tasks.",
    "Moderate memory load detected. System is fine.",
    "RAM is working efficiently. All is good."
)

$ramCommentsLow = @(
    "RAM usage is light. You have room for more tasks.",
    "Plenty of free memory available.",
    "Low memory usage detected. System is relaxed.",
    "RAM performance is optimal. All clear.",
    "Minimal RAM usage. System is calm.",
    "Memory load is low. Performance is smooth."
)

# Function to Select Random Comment Based on Threshold
function Get-RandomComment {
    param (
        [string]$Category,
        [string]$Usage
    )
    $diceRoll = Roll-Dice - 1  # Subtract 1 to make it zero-based for array indexing

    switch ($Category) {
        "CPU" {
            if ($Usage -ge 80) { return $cpuCommentsHigh[$diceRoll] }
            elseif ($Usage -ge 50) { return $cpuCommentsMedium[$diceRoll] }
            else { return $cpuCommentsLow[$diceRoll] }
        }
        "RAM" {
            if ($Usage -ge ($totalRAM * 0.75)) { return $ramCommentsHigh[$diceRoll] }
            elseif ($Usage -ge ($totalRAM * 0.5)) { return $ramCommentsMedium[$diceRoll] }
            else { return $ramCommentsLow[$diceRoll] }
        }
    }
}

# Fetch and Normalize CPU Usage
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, `
        @{Name="CPU_Usage"; Expression={
            $usage = [math]::Round(($_.CPU / $logicalProcessors), 2)
            if ($usage -gt 100) { 100 } else { $usage } }}

$topRAM = Get-Process | Sort-Object PM -Descending | `
    Select-Object -First 5 -Property ProcessName, `
    @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Generate Recommendations
$upgrades = Get-RecommendedUpgrades
$recommendedCPU = $upgrades.CPU
$recommendedRAM = $upgrades.RAM
$upgradeSearchQuery = $upgrades.Search

# Generate Report
$cpuComment = Get-RandomComment -Category "CPU" -Usage $cpuLoad
$ramComment = Get-RandomComment -Category "RAM" -Usage ($totalRAM - $availableRAM)

$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - CPU working hard." }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - RAM under load." }

$report = @"
**System Resource Report**

**CPU Name:** $cpuName  
**CPU Usage:** $cpuLoad% - $cpuComment  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB - $ramComment  

**Top 5 CPU Usage:**
$($cpuReport -join "`n")

**Top 5 RAM Usage:**
$($ramReport -join "`n")

**Recommended Upgrades:**
- **CPU:** $recommendedCPU
- **RAM:** $recommendedRAM

**Search Query for Upgrades:**
$upgradeSearchQuery

Report generation complete!
"@

# Step 3: Write Debug File
$debugPath = "$env:TEMP\system_report_debug.txt"
Show-ProgressBar -DelaySeconds 2 -TaskName "Writing Report to Debug File"
$report | Out-File -FilePath $debugPath -Encoding UTF8
Start-Process notepad.exe $debugPath

# Step 4: Send Report to Discord
Show-ProgressBar -DelaySeconds 2 -TaskName "Sending Report to Discord"
$msg = @{ content = $report } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
} catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}
