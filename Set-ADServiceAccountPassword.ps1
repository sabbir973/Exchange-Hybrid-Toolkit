<#
.SYNOPSIS
    Updates an Active Directory user or service account password securely.
.DESCRIPTION
    This script safely updates an Active Directory account password using secure strings.
    It prompts the administrator for input rather than storing cleartext passwords 
    in the script file.
.PARAMETER AccountName
    The SAMAccountName, DistinguishedName, or PrincipalName of the target AD account.
.EXAMPLE
    .\Set-ServiceAccountPassword.ps1 -AccountName "CloudLinkSvc"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The target AD account name.")]
    [string]$AccountName
)

begin {
    Write-Verbose "Initializing password update sequence for $AccountName."
}

process {
    try {
        # Verify the account exists in AD first
        $Account = Get-ADUser -Identity $AccountName -ErrorAction Stop
        
        Write-Host "Securely prompting for credentials..." -ForegroundColor Cyan
        
        # Prompt securely for the old and new passwords without masking or displaying cleartext
        $OldPassSecure = Read-Host -AsSecureString "Enter CURRENT password for $AccountName"
        $NewPassSecure = Read-Host -AsSecureString "Enter NEW password for $AccountName"

        if (-not $OldPassSecure -or -not $NewPassSecure) {
            Write-Warning "Passwords cannot be blank."
            return
        }

        Write-Host "Applying password change in Active Directory..." -ForegroundColor Yellow
        
        # Execute the update
        $Account | Set-ADAccountPassword -OldPassword $OldPassSecure -NewPassword $NewPassSecure -ErrorAction Stop

        Write-Host "Successfully updated the password for account: $($Account.SamAccountName)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to update password for $AccountName. Reason: $_"
    }
}

end {
    Write-Verbose "Execution completed."
}
