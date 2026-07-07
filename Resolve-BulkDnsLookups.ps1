<#
.SYNOPSIS
    Performs batch DNS lookups for a list of domains and exports the consolidated results.
.DESCRIPTION
    Accepts multiple domains via a comma-separated host prompt, resolves their target IP addresses 
    using native DNS lookup mechanisms, and outputs the final collection directly to a CSV file.
    Designed for engineering teams needing to audit or check multiple domain resolutions at once.
.NOTES
    Outputs directly to the current user's desktop dynamically.
#>

# --- CONFIGURATION (Customize for your environment) ---
$OutputCSVPath = "$env:USERPROFILE\Desktop\nslookupResults.csv"
# ------------------------------------------------------

$Domains = Read-Host "Please enter the domains to query (comma-separated)"
if ([string]::IsNullOrWhiteSpace($Domains)) {
    Write-Warning "No domains provided. Exiting."
    exit
}

$DomainArray = $Domains -split ',' | ForEach-Object { $_.Trim() }
$results = @()

foreach ($Domain in $DomainArray) {
    Write-Host "Querying DNS records for: $Domain" -ForegroundColor Cyan
    
    try {
        # Use native PowerShell DNS resolution for cleaner object handling
        $dnsLookup = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop | Select-Object -First 1
        $ipAddress = $dnsLookup.IPAddress
        $status    = "Success"
    } catch {
        $ipAddress = "Resolution Failed"
        $status    = $_.Exception.Message
    }

    $results += [PSCustomObject]@{
        "Domain"       = $Domain
        "Resolution"   = $status
        "IPAddress"    = $ipAddress
    }
}

# Export results to the desktop path
$results | Export-Csv -Path $OutputCSVPath -NoTypeInformation
Write-Host "`nProcess complete. Results exported to: $OutputCSVPath" -ForegroundColor Green
