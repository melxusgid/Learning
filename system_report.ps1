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
    "CPU melting, your machine might need ice.",
    "Overworked CPU is waving a white flag.",
    "The CPU marathon continues - uphill it is.",
    "CPU on fire, it cannot go faster.",
    "Your CPU is juggling too many tasks.",
    "A nap the CPU needs, work too much it does."
)

$cpuCommentsMedium = @(
    "CPU working steadily - balance it maintains.",
    "Moderate load, your CPU is not stressed.",
    "CPU holding up fine, but watch the load.",
    "CPU multitasking, calm and collected.",
    "Steady CPU performance, ready for more tasks.",
    "Balanced load your CPU has - wise usage, hmm."
)

$cpuCommentsLow = @(
    "CPU resting - a coffee break it takes.",
    "CPU idling happily - no stress it feels.",
    "Light load - CPU coasting like a cloud.",
    "Barely working, your CPU is chilling.",
    "CPU at peace, minimal tasks it handles.",
    "Your CPU finds serenity in idleness."
)

$ramCommentsHigh = @(
    "RAM overloaded, bursting it feels.",
    "Memory chaos - too many things open.",
    "RAM begging for relief - upgrade you should.",
    "RAM nearing its limits - warning you, it is.",
    "Memory wrestling match - upgrade needed soon.",
    "Full your RAM is - suffering, it is."
)

$ramCommentsMedium = @(
    "RAM under pressure, but holding steady.",
    "Moderate load - your RAM manages for now.",
    "RAM working efficiently - stable it remains.",
    "Memory load balanced, watch for spikes.",
    "RAM maintaining order, a little stress it shows.",
    "Your RAM works hard but stays controlled."
)

$ramCommentsLow = @(
    "RAM free and clear, space there is plenty.",
    "Low memory usage - all is calm.",
    "RAM relaxing, tasks are light.",
    "Peaceful RAM, your system hums along.",
    "RAM usage low - room to grow, there is.",
    "Calm and idle, your RAM feels at ease."
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

# Fetch and Normalize CPU Usage (Capped at 100%)
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, `
        @{Name="CPU_Usage"; Expression={
            $usage = [math]::Round(($_.CPU / $logicalProcessors), 2)
            if ($usage -gt 100) { 100 } else { $usage } }}

# Fetch Top RAM Processes
$topRAM = Get-Process | Sort-Object PM -Descending | `
    Select-Object -First 5 -Property ProcessName, `
    @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Generate Report
$cpuComment = Get-RandomComment -Category "CPU" -Usage $cpuLoad
$ramComment = Get-RandomComment -Category "RAM" -Usage ($totalRAM - $availableRAM)

$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - High usage, this is." }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - Using space wisely, it is." }

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
