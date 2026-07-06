<#
.SYNOPSIS
    Identifies all distribution groups without explicit write permissions (ownerless) and exports their members.
.DESCRIPTION
    This script scans all Exchange Distribution Groups, checks their Active Directory permissions 
    to see if any identity has write access to the 'member' attribute, and outputs groups 
    deemed "orphaned" or unmanaged along with their current membership lists.
.EXAMPLE
    .\Get-OrphanedDLMembers.ps1
.EXAMPLE
    .\Get-OrphanedDLMembers.ps1 | Export-Csv -Path "C:\temp\AllOrphanedDLs.csv" -NoTypeInformation
#>

[CmdletBinding()]
param ()

begin {
    Write-Verbose "Starting full environment scan for unmanaged/orphaned distribution groups."
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
}

process {
    try {
        Write-Verbose "Retrieving all distribution groups from Exchange..."
        # Querying all DLs using native high-performance parameter mapping
        $DLs = Get-DistributionGroup -ResultSize Unlimited

        foreach ($dl in $DLs) {
            Write-Verbose "Checking permissions for: $($dl.Name)"
            
            # Query Active Directory permissions for write access on the member attribute
            $permissions = Get-ADPermission -Identity $dl.DistinguishedName -ErrorAction SilentlyContinue | Where-Object {
                $_.Properties -like "member" -and
                @("ReadProperty", "WriteProperty") -isSubsetOf $_.AccessRights
            }

            # If no manager/owner permissions are found, group is considered orphaned
            if (-not $permissions) {
                Write-Host "Orphaned DL Found: $($dl.Name)" -ForegroundColor Yellow
                
                # Retrieve current members
                $members = Get-DistributionGroupMember -Identity $dl.Identity -ErrorAction SilentlyContinue | 
                           Select-Object -ExpandProperty PrimarySmtpAddress

                $memberString = if ($members) { $members -join "; " } else { "No Members" }

                $Results.Add([PSCustomObject]@{
                    DLName   = $dl.Name
                    DLEmail  = $dl.PrimarySmtpAddress
                    Members  = $memberString
                })
            }
        }
    }
    catch {
        Write-Error "An error occurred during execution: $_"
    }
}

end {
    # Output results to the pipeline
    if ($Results.Count -gt 0) {
        Write-Host "`nScan complete. Found $($Results.Count) orphaned distribution groups across the environment." -ForegroundColor Green
        $Results
    } else {
        Write-Host "`nScan complete. No orphaned distribution groups identified." -ForegroundColor Green
    }
}
