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

# Dynamic Comments
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

$cpuComment = $cpuCommentOptions | Get-Random
$ramComment = $ramCommentOptions | Get-Random

# Fetch and Normalize CPU Usage (Capped at 100%)
$topCPU = Get-Process | Where-Object { $_.CPU -ne $null } |
    Sort-Object CPU -Descending |
    Select-Object -First 5 -Property ProcessName, `
        @{Name="CPU_Usage"; Expression={[math]::Round(($_.CPU / $logicalProcessors), 2) -as [double]]}

# Adjust CPU Usage Percentage Cap
$topCPU = $topCPU | ForEach-Object {
    $_.CPU_Usage = if ($_.CPU_Usage -gt 100) { 100 } else { $_.CPU_Usage }
    $_
}

# Fetch Top RAM Processes
$topRAM = Get-Process | Sort-Object PM -Descending | `
    Select-Object -First 5 -Property ProcessName, `
    @{Name="RAM_Usage_MB"; Expression={[math]::Round($_.PM / 1MB, 2)}}

# Upgrade Suggestions
$recommendedRAM = if ($totalRAM -ge 16) {
    "Already sufficient RAM for current tasks."
} elseif ($totalRAM -lt 8) {
    "Upgrade to 16 GB RAM for smoother performance."
} elseif ($totalRAM -ge 8 -and $availableRAM -lt ($totalRAM * 0.25)) {
    "Upgrade to 16 GB or 32 GB RAM to handle your multitasking needs."
} else {
    "Upgrade to 16 GB RAM for optimal performance."
}

$cpuUpgrade = if ($cpuName -match "i3|i5|Ryzen 3") {
    "Upgrade to Intel i5/i7 10th Gen or newer / AMD Ryzen 5 3600 for a 1.5x performance boost."
} elseif ($cpuName -match "i7|Ryzen 5|Ryzen 7") {
    "CPU is sufficient for most tasks - no upgrade needed unless under heavy load."
} else {
    "Already sufficient for tasks."
}

# Add Relatable Comments
function Get-ProcessComment ($process) {
    if ($process -match "chrome|opera") { "Web browser - hogging resources." }
    elseif ($process -match "explorer") { "File explorer - system navigation." }
    elseif ($process -match "Discord") { "Chat app - critical for communication." }
    elseif ($process -match "MsMpEng") { "Antivirus - scanning for threats." }
    else { "Background task - using resources quietly." }
}

# Format CPU and RAM Reports
$cpuReport = $topCPU | ForEach-Object { "$($_.ProcessName) - $($_.CPU_Usage)% - $(Get-ProcessComment $_.ProcessName)" }
$ramReport = $topRAM | ForEach-Object { "$($_.ProcessName) - $($_.RAM_Usage_MB) MB - $(Get-ProcessComment $_.ProcessName)" }

# Build the Final Report
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

**Recommended Upgrades (1.5x to 2x Better):**
Your current specs are slowing things down. Here's what you need:
- **RAM:** $recommendedRAM
- **CPU:** $cpuUpgrade

Report generation complete!
"@

# Step 3: Write Debug File
$debugPath = "$env:TEMP\system_report_debug.txt"
Show-ProgressBar -DelaySeconds 2 -TaskName "Writing Report to Debug File"

# Ensure the file is not being accessed
if (Test-Path $debugPath) {
    try {
        Remove-Item -Path $debugPath -Force
    } catch {
        Write-Host "Failed to delete locked file. Please close it and try again." -ForegroundColor Red
        exit
    }
}

$report | Out-File -FilePath $debugPath -Encoding UTF8

if (Test-Path $debugPath) {
    Write-Host "Debug file successfully created!" -ForegroundColor Green
    Start-Process notepad.exe $debugPath
} else {
    Write-Host "Failed to create debug file. Please check script execution." -ForegroundColor Red
}

# Step 4: Send Report to Discord
Show-ProgressBar -DelaySeconds 2 -TaskName "Sending Report to Discord"
$msg = @{ content = $report } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
} catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}
