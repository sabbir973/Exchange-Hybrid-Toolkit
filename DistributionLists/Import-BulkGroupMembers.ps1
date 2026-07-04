<#
.SYNOPSIS
    Bulk Active Directory Group Membership Provisioning Utility.
.DESCRIPTION
    An enterprise administration script designed to import user accounts from a CSV 
    file and bulk-add them to a target Active Directory Distribution or Security Group. 
    Includes a dynamic visual progress indicator to track high-volume imports in real time.
.PARAMETER csvPath
    The local path to the source CSV file containing user identities.
.PARAMETER adGroup
    The Identity (Name, SamAccountName, or DistinguishedName) of the target AD group.
.EXAMPLE
    .\Import-BulkGroupMembers.ps1
#>

Write-Host "`n###### Bulk AD Group Membership Importer ######" -ForegroundColor Green

# Interactively prompt the operator for the target group and source file path
$adGroup = Read-Host "Enter the Target AD Group Name"
$csvPath = Read-Host "Enter the path to your CSV file (e.g., C:\temp\list.csv)"

# Validate inputs before processing
if ([string]::IsNullOrEmpty($adGroup) -or [string]::IsNullOrEmpty($csvPath)) {
    Write-Host "Error: Both Group Name and CSV Path are required." -ForegroundColor Red
    return
}

if (-not (Test-Path -Path $csvPath)) {
    Write-Host "Error: Cannot find the CSV file at path: $csvPath" -ForegroundColor Red
    return
}

try {
    # Import target user records from the verified CSV
    $users = Import-Csv -Path $csvPath
    $totalUsers = $users.Count
    $count = 0

    if ($totalUsers -eq 0) {
        Write-Host "The specified CSV file is empty." -ForegroundColor Yellow
        return
    }

    Write-Host "`nBeginning bulk import of $totalUsers members into '$adGroup'..." -ForegroundColor Yellow

    foreach ($user in $users) {
        # Ensure the CSV column header matches your column identity (e.g., 'ADID')
        if ($user.ADID) {
            try {
                Add-ADGroupMember -Identity $adGroup -Members $user.ADID -ErrorAction Stop
                $count++
            } catch {
                Write-Error "Failed to add user '$($user.ADID)' to group '$adGroup'. Error: $($_.Exception.Message)"
            }
        } else {
            Write-Host "Warning: Row skipped. Column header 'ADID' not found or empty." -ForegroundColor Yellow
        }
        
        # Calculate the percentage of completion dynamically
        $percentageComplete = ($count / $totalUsers) * 100
        
        # Render the interactive engine progress bar
        Write-Progress -Activity "Populating Active Directory Group Members" `
                       -Status "$count of $totalUsers records processed" `
                       -PercentComplete $percentageComplete
    }

    Write-Host "`n[Success] Bulk operations complete. $count users successfully added to group '$adGroup'." -ForegroundColor Green

} catch {
    Write-Error "An unexpected error occurred during execution: $($_.Exception.Message)"
}
