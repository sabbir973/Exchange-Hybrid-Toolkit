<#
.SYNOPSIS
    Monitors Recoverable Items folder sizes and automates Auto-Expanding Archive deployment.
.DESCRIPTION
    Checks a collection of target mailboxes for Recoverable Items folders nearing quota limits (90GB+). 
    If found, it provisions Auto-Expanding Archives, pauses for execution convergence, and triggers
    the Managed Folder Assistant with a FullCrawl switch to process the queue.
.NOTES
    Requires administrative permissions over Exchange Online Management modules.
#>

function Connect-Services {
    try {
        $connectionInfo = Get-ConnectionInformation 
        $isConnected = $connectionInfo | Where-Object { $_.Name -like "ExchangeOnline*" -and $_.State -eq "Connected" }
        
        if (-not $isConnected) { 
            Connect-ExchangeOnline -ErrorAction Stop 
        }
    } catch {
        Write-Host "Failed to connect to services: Check authentication/PIM privileges. Error: $_" -ForegroundColor Red
        throw $_
    }
}

# Run service connection validation
Connect-Services

$userInput = Read-Host "Enter target user emails or Account IDs (comma-separated)"
if ([string]::IsNullOrWhiteSpace($userInput)) {
    Write-Warning "No target inputs provided. Exiting script."
    exit
}

$usersArray = $userInput -split ',' | ForEach-Object { $_.Trim() }
$needsConvergenceSleep = $false

foreach ($user in $usersArray) {
    Write-Host "Analyzing storage utilization for: $user" -ForegroundColor Cyan
    
    $folderStats = Get-MailboxFolderStatistics -Identity $user -FolderScope RecoverableItems -Archive -ErrorAction SilentlyContinue
    if (-not $folderStats) {
        Write-Warning "Could not retrieve folder statistics for $user. Skipping."
        continue
    }

    # Extract numeric GB size safely by isolating the byte value or parentheses data
    $rawSizeString = ($folderStats.FolderAndSubfolderSize -split '\(')[1] -replace '[^0-9\.]', ''
    $folderSize = [math]::Round(([int64]$rawSizeString) / 1GB, 2)

    $userMailbox = Get-Mailbox -Identity $user -ErrorAction SilentlyContinue
    if (-not $userMailbox) { continue }

    # Check optimization thresholds
    if (-not $userMailbox.AutoExpandingArchiveEnabled -and $folderSize -gt 90) {
        Write-Host "Enabling Auto-Expanding Archive for $user (Current Size: $folderSize GB)..." -ForegroundColor Yellow
        Enable-Mailbox -Identity $user -AutoExpandingArchive
        $needsConvergenceSleep = $true
    } 
    elseif ($userMailbox.AutoExpandingArchiveEnabled) {
        Write-Output "User $user already has Auto-Expanding Archive configuration applied."
    }
}

# Pause execution for cloud provisioning pipeline processing if changes were applied
if ($needsConvergenceSleep) {
    Write-Output "`n[System Notification] Pausing execution pipeline for 10 minutes to allow cloud archive provisioning..."
    Start-Sleep -Seconds 600
}

# Final Processing Run
foreach ($user in $usersArray) {
    $folderStats = Get-MailboxFolderStatistics -Identity $user -FolderScope RecoverableItems -Archive -ErrorAction SilentlyContinue
    if (-not $folderStats) { continue }

    $rawSizeString = ($folderStats.FolderAndSubfolderSize -split '\(')[1] -replace '[^0-9\.]', ''
    $folderSize = [math]::Round(([int64]$rawSizeString) / 1GB, 2)

    if ($folderSize -gt 90) {
        Write-Host "Triggering Managed Folder Assistant FullCrawl for $user ($folderSize GB)..." -ForegroundColor Green
        Start-ManagedFolderAssistant -Identity $user -FullCrawl
    } else {
        Write-Output "Folder optimization skipped: $user remains below the 90GB capacity line ($folderSize GB)."
    }
}
