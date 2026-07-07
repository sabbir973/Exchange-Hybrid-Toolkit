<#
.SYNOPSIS
    Cross-checks and manages group memberships across Active Directory and Exchange Online.
.DESCRIPTION
    This script identifies mailboxes, pulls their associated security/distribution groups, 
    and verifies that memberships mirror correctly across both on-premises AD and Exchange Online.
    Great for hybrid environments managing shared mailbox access via synchronized groups.
.NOTES
    Adjust the configuration variables below to match your organization's naming standards.
#>

# --- CONFIGURATION (Customize for your environment) ---
$GlobalCatalogServer = "yourdomain.com:3268"  # Your internal Active Directory Global Catalog
$SyncGroupPrefix     = "user-"                    # Prefix for your standard user/synchronized groups
$AdminGroupPrefix    = "admin-"                   # Prefix for your elevated/administrative groups
$UserGroupSuffix     = "User"                     # Suffix string used for standard user groups
$AdminGroupSuffix    = "Admin"                    # Suffix string used for administrative groups
# ------------------------------------------------------

function Connect-Services {
    try {
        # Check if already connected to Exchange Online 
        $connectionInfo = Get-ConnectionInformation 
        $isConnected = $connectionInfo | Where-Object { $_.Name -like "ExchangeOnline*" -and $_.State -eq "Connected" }
        
        if (-not $isConnected) { 
            Connect-ExchangeOnline -ErrorAction Stop 
        }
    } catch {
        Write-Host "Failed to connect to services: Check your authentication/PIM and VPN connection. Error: $_" -ForegroundColor Red
        throw $_
    }
}

# Module Pre-checks
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Warning "ActiveDirectory module is missing. Please install RSAT."
}
if (-not (Get-Module -Name ExchangeOnlineManagement -ListAvailable)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Cyan
    Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
}

# Establish connections
Connect-Services

do {
    $sharedMailbox = Read-Host "Enter Shared Mailbox Name or Email"
    if ([string]::IsNullOrWhiteSpace($sharedMailbox)) { continue }

    Write-Host "`nProcessing Shared Mailbox: $sharedMailbox" -ForegroundColor Yellow
    Write-Host "======================================================="

    # Check Shared Mailbox
    $checkSharedMailbox = Get-Mailbox $sharedMailbox -ErrorAction SilentlyContinue | 
        Where-Object { ($_.RecipientTypeDetails -eq "SharedMailbox") -or ($_.Name -eq "Team Mailbox") }

    if (-not $checkSharedMailbox) {
        Write-Host "Shared Mailbox not found. Check your input and search again." -ForegroundColor Red
        $continue = Read-Host "`nDo you want to process another shared mailbox?(Y/N)"
        continue
    }

    # Retrieve mailbox permissions matching configured prefix
    $mailboxPermissions = Get-MailboxPermission -Identity $checkSharedMailbox | 
        Where-Object { $_.User -like "$SyncGroupPrefix*" }

    if ($mailboxPermissions) {
        foreach ($permission in $mailboxPermissions) {
            $currentSyncGroup = $permission.User
    
            $adUserGroup = Get-ADObject -Server $GlobalCatalogServer -Properties CanonicalName, whenCreated -Filter "SamAccountName -eq '$currentSyncGroup'"
            if (-not $adUserGroup) {
                Write-Host "Group $currentSyncGroup not found in Active Directory global catalog." -ForegroundColor Red
                continue
            }

            $adGroupCanonicalName = $adUserGroup.CanonicalName
            $userGroupDomain = ($adGroupCanonicalName -split '\.')[0]
            $whenCreated = ($adUserGroup.whenCreated -split ' ')[0]
    
            # Prompt user to filter down a specific identity
            $usersToSearchInput = Read-Host "Please enter the user email or Account ID (Leave blank to show all)"
            $usersToSearch = $null

            if (-not [string]::IsNullOrEmpty($usersToSearchInput)) {
                try {
                    $userMailboxValue = Get-Mailbox -Identity $usersToSearchInput -ErrorAction Stop
                    $usersToSearch = $userMailboxValue.Alias
                } catch {
                    Write-Error "Failed to retrieve mailbox for the provided identity '$usersToSearchInput'."
                    continue
                }
            }

            # Get Exchange Online group members
            $ExchonlineGroupMembers = Get-DistributionGroupMember -Identity $currentSyncGroup -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($usersToSearch)) {
                $ExchonlineGroupMembers = $ExchonlineGroupMembers | Where-Object { ($_.PrimarySmtpAddress -like "*$usersToSearch*") -or ($_.Alias -like "*$usersToSearch*") }
            }
    
            # Search group members in AD
            $adUserGroupMembers = Get-ADGroupMember -Identity $currentSyncGroup -Server "$userGroupDomain" -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($usersToSearch)) {
                $adUserGroupMembers = $adUserGroupMembers | Where-Object { ($_.PrimarySmtpAddress -like "*$usersToSearch*") -or ($_.SamAccountName -like "*$usersToSearch*") }
            }
    
            # Map Exchange Online users for fast lookup
            $ExchonlineGroupMembersHash = @{}
            foreach ($ExchangeMember in $ExchonlineGroupMembers) {
                if ($ExchangeMember.Alias) {
                    $ExchonlineGroupMembersHash[$ExchangeMember.Alias.ToLower()] = $true
                }
            }
                
            # Create custom objects for output
            $output = foreach ($member in $adUserGroupMembers) {
                $accountId = $member.SamAccountName
                $userMailbox = Get-Mailbox -Identity $accountId -ErrorAction SilentlyContinue
                
                $userCanonicalName = Get-ADObject -Server $GlobalCatalogServer -Properties CanonicalName -Filter "SamAccountName -eq '$accountId'"
                $userDomainName = if ($userCanonicalName) { ($userCanonicalName.CanonicalName -split '\.')[0] } else { "Unknown" }
                
                [PSCustomObject]@{
                    'DisplayName'          = $userMailbox.DisplayName
                    'AccountID'            = $accountId 
                    'PrimarySmtpAddress'   = $userMailbox.PrimarySmtpAddress
                    'Domain'               = $userDomainName.ToUpper()
                    'UserInExchangeOnline' = [bool]$ExchonlineGroupMembersHash[$accountId.ToLower()]
                }
            }
        
            if ($output) {
                Write-Host "`nCross-checking user sync state:" -ForegroundColor DarkCyan
                Write-Host "User Group: $currentSyncGroup" -ForegroundColor DarkYellow
                Write-Host "Domain: $($userGroupDomain.ToUpper())" -ForegroundColor DarkYellow
                Write-Host "When Created: $whenCreated" -ForegroundColor DarkYellow
    
                $output | Format-Table -Property DisplayName, AccountID, PrimarySmtpAddress, Domain, UserInExchangeOnline -AutoSize
            } else {
                try {
                    Write-Output "`nChecking Active Directory, no member found in $currentSyncGroup`n"
                    if ([string]::IsNullOrEmpty($usersToSearch)) { "No matching membership records found."; continue }

                    $addOption = Read-Host "To add user $usersToSearch into Exchange Online group, enter (yes/y)"
                    if ($addOption -match "^(yes|y)$") {
                        Add-DistributionGroupMember -Identity $currentSyncGroup -Member $usersToSearch -BypassSecurityGroupManagerCheck
                        Write-Output "`nThe command completed successfully.`n"
                    } else {
                        Write-Host "Aborting addition request."
                    }
                } catch {
                    if ($_ -match 'The recipient ".*" is already a member of the group') {
                        Write-Host "$($Matches[0]) in Exchange Online.`n`n" -ForegroundColor Red
                    } else {
                        Write-Error $_
                    }
                }
            }
        }
    } else {
        Write-Host "Configured user group pattern not assigned to this Shared Mailbox." -ForegroundColor Red
        $targetGroup = Read-Host "Enter a group name to assign permissions manually"
        
        if (-not [string]::IsNullOrWhiteSpace($targetGroup)) {
            $addOption = Read-Host "To commit permission assignments, enter (yes/y)"
            if ($addOption -match "^(yes|y)$") {
                Add-RecipientPermission -Identity $checkSharedMailbox -Trustee $targetGroup -AccessRights SendAs -Confirm:$false
                Add-MailboxPermission -Identity $checkSharedMailbox -User $targetGroup -AccessRights FullAccess -InheritanceType All -Confirm:$false
                Write-Output "`nThe assignment command completed successfully."
            }
        }
    }
    
    # Process Associated Administrative Mirror Groups
    if ($mailboxPermissions) {
        foreach ($perm in $mailboxPermissions) {
            # Safely string-replace targeted naming convention models using top parameters
            $targetAdminGroup = $perm.User -replace [regex]::Escape($SyncGroupPrefix), $AdminGroupPrefix -replace [regex]::Escape($UserGroupSuffix), $AdminGroupSuffix
     
            $adminGroup = Get-ADObject -Server $GlobalCatalogServer -Properties CanonicalName -Filter "SamAccountName -eq '$targetAdminGroup'"
            if (-not $adminGroup) { continue }
     
            $domain = ($adminGroup.CanonicalName -split '/')[0]
             
            if (-not [string]::IsNullOrWhiteSpace($domain)) {
                $adminGroupMembers = Get-ADGroupMember -Identity $targetAdminGroup -Server "$domain" -ErrorAction SilentlyContinue
            } else {
                Write-Host "Domain scope extraction failed or returned null." -ForegroundColor DarkRed
                $adminGroupMembers = $null
            }
     
            if ($adminGroupMembers) {
                Write-Host "`nAdmin Mirror Group (Active Directory Exclusive):" -ForegroundColor DarkCyan
                Write-Host "Admin Group: $targetAdminGroup" -ForegroundColor DarkYellow
                
                $customTable = foreach ($adminMember in $adminGroupMembers) {
                    $accountId = $adminMember.SamAccountName
                    $mailbox = Get-Mailbox -Identity $accountId -ErrorAction SilentlyContinue
     
                    [PSCustomObject]@{
                        'Name'               = $mailbox.DisplayName
                        'AccountID'          = $mailbox.Alias
                        'PrimarySmtpAddress' = $mailbox.PrimarySmtpAddress
                    }
                }
                $customTable | Format-Table -AutoSize
            } else {
                Write-Host "No members found in $targetAdminGroup" -ForegroundColor Red
            }
        }
    }
    
    $continue = Read-Host "`nDo you want to process another shared mailbox?(Y/N)"
} while ($continue -match "^(yes|y)$")
