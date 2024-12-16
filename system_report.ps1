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

# Step 1: Collect System Specs
Show-ProgressBar -DelaySeconds 3 -TaskName "Gathering System Information"

$cpuLoad = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue, 2)
$totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$availableRAM = [math]::Round((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024, 2)
$cpuName = (Get-CimInstance Win32_Processor).Name
$logicalProcessors = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

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

# Generate the Report
$report = @"
**System Resource Report**

**CPU Name:** $cpuName  
**CPU Usage:** $cpuLoad% - $cpuComment  
**Total RAM:** $totalRAM GB  
**Available RAM:** $availableRAM GB - $ramComment  

Report generation complete!
"@

# Step 2: Write Debug File
$debugPath = "$env:TEMP\system_report_debug.txt"
Show-ProgressBar -DelaySeconds 2 -TaskName "Writing Report to Debug File"
$report | Out-File -FilePath $debugPath -Encoding UTF8

if (Test-Path $debugPath) {
    Write-Host "Debug file successfully created!" -ForegroundColor Green
    Start-Process notepad.exe $debugPath
} else {
    Write-Host "Failed to create debug file. Please check script execution." -ForegroundColor Red
}

# Step 3: Send Report to Discord
Show-ProgressBar -DelaySeconds 2 -TaskName "Sending Report to Discord"
$msg = @{ content = $report } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $msg -ContentType 'application/json'
    Write-Host "Report successfully sent!" -ForegroundColor Green
} catch {
    Write-Host "Failed to send the report: $_" -ForegroundColor Red
}
