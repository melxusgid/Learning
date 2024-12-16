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
        Write-Host -NoNewline "`rProgress: $i / $DelaySeconds seconds"
        Start-Sleep -Seconds 1
    }
    Write-Host "`r[Done] $TaskName completed!`n" -ForegroundColor Green
}

# Function to simulate a dice roll for random comments
function Roll-Dice {
    return Get-Random -Minimum 0 -Maximum 6  # Rolls between 0 and 5 for array indexing
}

# Step 1: Gather Current System Specs
Show-ProgressBar -DelaySeconds 3 -TaskName "Gathering System Information"

# Collect System Data
$totalLogicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
$cpuLoad = [math]::Round(((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples | 
                         Measure-Object -Property CookedValue -Sum).Sum / $totalLogicalProcessors, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)
$cpuName = (Get-CimInstance Win32_Processor).Name

# CPU and RAM Comment Pools
$cpuCommentsHigh = @(
    "Your CPU is under heavy load. Consider closing unused programs.",
    "The CPU is maxed out. Performance might slow down.",
    "Your CPU is working hard. Monitor it closely.",
    "High CPU usage detected. Try reducing background tasks.",
    "CPU load is at its limit. Things might lag.",
    "Heavy CPU usage detected. This could impact performance."
)

$cpuCommentsMedium = @(
    "Your CPU is performing well with moderate load.",
    "CPU usage is balanced and stable.",
    "Moderate CPU usage. System performance looks good.",
    "CPU is handling tasks efficiently.",
    "CPU load is moderate. No issues detected.",
    "Your CPU is working normally without stress."
)

$cpuCommentsLow = @(
    "Your CPU is idle with minimal load.",
    "CPU usage is very low. System is running smoothly.",
    "Light CPU activity detected. No problems here.",
    "CPU is barely working. All systems are go.",
    "Minimal CPU usage. Performance is optimal.",
    "Your CPU is relaxed and ready for more work."
)

$ramCommentsHigh = @(
    "Your RAM is almost full. Close unused applications.",
    "High RAM usage detected. System may slow down.",
    "RAM is under heavy load. Consider upgrading memory.",
    "Low available RAM. System performance may suffer.",
    "RAM usage is high. Free up memory if possible.",
    "Running out of memory. Close unnecessary tasks."
)

$ramCommentsMedium = @(
    "Your RAM usage is moderate. System is stable.",
    "RAM is being used efficiently. No issues detected.",
    "Memory usage is balanced and manageable.",
    "RAM is working well under current load.",
    "Moderate memory usage. System is performing fine.",
    "RAM usage is under control with no problems."
)

$ramCommentsLow = @(
    "Plenty of free RAM. System performance is excellent.",
    "Your RAM usage is very low. No concerns here.",
    "Minimal RAM usage detected. System is fast and responsive.",
    "RAM usage is light. You have room for more tasks.",
    "Lots of free memory. Everything looks good.",
    "System memory is relaxed and ready for more work."
)

# Function to Select Random Comment Based on Usage Thresholds
function Get-RandomComment {
    param (
        [string]$Category,
        [double]$Usage
    )
    $diceRoll = Roll-Dice

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

# Fetch Top CPU Processes (Accurately Capped)
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, `
        @{Name="CPU_Usage"; Expression={
            $usage = [math]::Round(($_.CPU / $totalLogicalProcessors), 2)
            if ($usage -gt 100) { 100 } else { $usage } }}

# Fetch Top RAM Processes
$topRAM = Get-Process | Sort-Object PM -Descending | `
    Select-Object -First 5 -Property ProcessName, `
    @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Generate Report
$cpuComment = Get-RandomComment -Category "CPU" -Usage $cpuLoad
$ramComment = Get-RandomComment -Category "RAM" -Usage ($totalRAM - $availableRAM)

$cpuReport = $topCPU | ForEach-Object {
    "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-RandomComment -Category 'CPU' -Usage $_.CPU_Usage)"
}

$ramReport = $topRAM | ForEach-Object {
    "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $(Get-RandomComment -Category 'RAM' -Usage $_.RAM_Usage_MB)"
}

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
