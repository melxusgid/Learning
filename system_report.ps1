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

# Fetch Top CPU Processes and Normalize Usage
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, `
        @{Name="CPU_Usage"; Expression={
            $usage = [math]::Round(($_.CPU / $logicalProcessors), 2)
            if ($usage -gt 100) { 100 } else { $usage }
        }}

# Generate Comments for Each Top CPU Process
$cpuReport = $topCPU | ForEach-Object {
    $comment = if ($_.CPU_Usage -ge 80) {
        "This process is consuming high CPU resources. Performance may degrade."
    } elseif ($_.CPU_Usage -ge 50) {
        "Moderate CPU usage detected. Monitor this process."
    } else {
        "Low CPU usage. No concerns here."
    }
    "$($_.ProcessName) - $($_.CPU_Usage)% - $comment"
}

# Fetch Top RAM Processes
$topRAM = Get-Process | Sort-Object PM -Descending | `
    Select-Object -First 5 -Property ProcessName, `
    @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Generate Comments for Each Top RAM Process
$ramReport = $topRAM | ForEach-Object {
    $comment = if ($_.RAM_Usage_MB -ge ($totalRAM * 0.75)) {
        "High RAM usage detected. Free up memory if possible."
    } elseif ($_.RAM_Usage_MB -ge ($totalRAM * 0.5)) {
        "Moderate RAM usage. Keep an eye on memory usage."
    } else {
        "Low RAM usage. System memory is stable."
    }
    "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $comment"
}

# Recommended Upgrades
$recommendedRAM = if ($totalRAM -lt 8) {
    "Upgrade to at least 16GB RAM for smoother performance."
} elseif ($totalRAM -lt 16) {
    "Upgrade to 32GB RAM to handle more multitasking."
} else {
    "RAM is sufficient for current tasks."
}

$recommendedCPU = if ($cpuName -match "i3|i5|Ryzen 3") {
    "Upgrade to Intel i5 10th Gen or AMD Ryzen 5 for better performance."
} elseif ($cpuName -match "i7|Ryzen 5") {
    "Your CPU is sufficient for most tasks but could be upgraded for heavy workloads."
} else {
    "Your CPU is performing well for current tasks."
}

# Add Execution Time and Date
$startTime = Get-Date
$executionStart = [System.Diagnostics.Stopwatch]::StartNew()

# Generate Final Report
$executionStart.Stop()
$executionTime = "{0:hh\:mm\:ss}" -f $executionStart.Elapsed

$report = @"
**System Resource Report**

**Date/Time:** $($startTime.ToString("MM/dd/yyyy HH:mm"))  
**Execution Time:** $executionTime  

**CPU Name:** $cpuName  
**CPU Usage:** $cpuLoad% - System running smoothly.  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB  

**Top 5 CPU Usage:**
$($cpuReport -join "`n")

**Top 5 RAM Usage:**
$($ramReport -join "`n")

**Recommended Upgrades:**
- CPU: $recommendedCPU  
- RAM: $recommendedRAM

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
