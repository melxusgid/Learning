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

# Record Script Start Time
$startTime = Get-Date

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
    "CPU running hot. System might slow down.",
    "Your CPU is working overtime. Tasks are piling up.",
    "High CPU usage detected. Performance could drop."
)

$ramCommentsHigh = @(
    "Low available RAM. System performance may suffer.",
    "RAM usage is high. Free up memory if possible.",
    "High RAM usage detected. System may slow down.",
    "Running out of memory. Close unnecessary tasks.",
    "RAM is nearing its limit. Consider an upgrade.",
    "System memory under pressure. Performance may drop."
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
            else { return "CPU usage is low. All systems are running smoothly." }
        }
        "RAM" {
            if ($Usage -ge ($totalRAM * 0.75)) { return $ramCommentsHigh[$diceRoll] }
            else { return "RAM usage is light. You have room for more tasks." }
        }
    }
}

# Fetch Top CPU Processes
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

# Generate Comments and Report
$cpuComment = Get-RandomComment -Category "CPU" -Usage $cpuLoad
$ramComment = Get-RandomComment -Category "RAM" -Usage ($totalRAM - $availableRAM)

$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $cpuComment" }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $ramComment" }

# Record Script End Time and Calculate Duration
$endTime = Get-Date
$duration = New-TimeSpan -Start $startTime -End $endTime
$executionTime = "{0:hh\:mm\:ss}" -f $duration

# Add Date and Time to Report
$currentDateTime = $startTime.ToString("MM/dd/yyyy HH:mm")

$report = @"
**System Resource Report**

**Date/Time:** $currentDateTime  
**Execution Time:** $executionTime  

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
