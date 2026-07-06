<#
.SYNOPSIS
    Exchange Online Global Cloud Archive Enablement Tool.
.DESCRIPTION
    A production-ready administrative script that connects to Exchange Online, 
    retrieves all standard User Mailboxes across the tenant, and ensures the 
    cloud archive feature is enabled for every user. Includes real-time 
    visual progress tracking.
.EXAMPLE
    .\Enable-AllMailboxArchives.ps1
#>

Write-Host "`n###### Tenant-Wide Cloud Archive Enablement Utility ######" -ForegroundColor Green

try {
    Write-Host "Ensure you are connected to Exchange Online (Connect-ExchangeOnline) before running." -ForegroundColor Cyan
    Write-Host "Querying Exchange Online for all user mailboxes..." -ForegroundColor Yellow
    
    # Retrieve all standard user mailboxes across the entire tenant
    $mailboxes = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited

    $total = $mailboxes.Count
    $count = 0

    if ($total -eq 0) {
        Write-Host "No user mailboxes discovered in the tenant." -ForegroundColor Yellow
        return
    }

    Write-Host "Discovered $total total mailboxes. Initiating archival enablement sweep..." -ForegroundColor Yellow

    foreach ($mailbox in $mailboxes) {
        $count++
        
        # Calculate dynamic completion percentage
        $percentComplete = ($count / $total) * 100
        
        # Update runtime progress indicator
        Write-Progress -Activity "Enabling Cloud Archives Globally" `
                       -Status "Processing $count of $total: $($mailbox.UserPrincipalName)" `
                       -PercentComplete $percentComplete

        try {
            # Enable archive feature safely using the mailbox alias
            Enable-Mailbox -Identity $mailbox.Alias -Archive -ErrorAction Stop
        } catch {
            Write-Error "Failed to enable archive for: $($mailbox.UserPrincipalName). Error: $($_.Exception.Message)"
        }
    }

    # Close out the progress loop completely
    Write-Progress -Activity "Enabling Cloud Archives Globally" -Completed -Status "All mailboxes processed."
    Write-Host "`n[Success] Tenant-wide archive sweep complete. Total mailboxes processed: $count" -ForegroundColor Green

} catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
}
