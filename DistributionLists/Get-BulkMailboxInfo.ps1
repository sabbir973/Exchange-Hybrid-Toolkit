<#
.SYNOPSIS
    Bulk retrieves Exchange Online mailbox information from a CSV list of emails.
.DESCRIPTION
    This script imports a CSV file containing an email column, processes all identities 
    simultaneously in a single high-performance query block using Exchange Online cmdlets, 
    and exports the detailed results back to a target CSV file.
.PARAMETER InputCsv
    The full path to the source CSV file containing user email addresses.
.PARAMETER OutputCsv
    The full path where the compiled mailbox details should be exported.
.EXAMPLE
    .\Get-BulkMailboxInfo.ps1 -InputCsv "C:\Temp\Directors.csv" -OutputCsv "C:\Temp\MailboxDetails.csv"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the input CSV file.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputCsv,

    [Parameter(Mandatory = $true, HelpMessage = "Path where the output CSV should be saved.")]
    [string]$OutputCsv
)

begin {
    Write-Verbose "Initializing bulk mailbox info retrieval process."
}

process {
    try {
        Write-Verbose "Reading input data from: $InputCsv"
        # Extract the email column directly into a clean array
        $EmailArray = (Import-Csv -Path $InputCsv).email

        if (-not $EmailArray) {
            Write-Warning "The specified CSV did not contain any data or is missing the 'email' column header."
            return
        }

        Write-Host "Found $($EmailArray.Count) target email identities to process." -ForegroundColor Cyan
        Write-Host "Querying Exchange Online Mailboxes..." -ForegroundColor Yellow

        # High-performance batch execution passing the entire array directly to the pipeline
        $Results = Get-EXOMailbox -Identity $EmailArray -ErrorAction SilentlyContinue | 
                   Select-Object DisplayName, Alias, PrimarySmtpAddress

        if ($Results) {
            Write-Host "Successfully retrieved profile details. Exporting data to: $OutputCsv" -ForegroundColor Green
            $Results | Export-Csv -Path $OutputCsv -NoTypeInformation
        } else {
            Write-Warning "No active mailboxes matched the provided email criteria."
        }
    }
    catch {
        Write-Error "Failed to process bulk mailbox lookup. Reason: $_"
    }
}

end {
    Write-Verbose "Script processing finalized."
}
