# Exchange-Hybrid-Toolkit

A production-ready PowerShell automation suite designed for Enterprise system administrators managing hybrid identities and mail infrastructure. This toolkit provides modular, highly optimized utilities to streamline Active Directory account auditing, Exchange Online mailbox maintenance, recursive DNS triage, and synchronized group policy enforcement.

---

## 📁 Repository Structure

The toolkit is organized into specialized modules to make navigation and deployment straightforward:

*   **`DNS/`** — Network triage and infrastructure resolution utilities.
    *   `Resolve-BulkDnsLookups.ps1` — Fast, native PowerShell `Resolve-DnsName` utility to parse domain lists.
    *   `Resolve-BatchDnsDetails.ps1` — Comprehensive legacy `nslookup` parser that tracks targeting servers with built-in request delays.
*   **`DistributionLists/`** — On-premises and cloud distribution group auditing.
*   **`MailboxOptimization/`** — Automated mailbox maintenance and storage quota governance.
    *   `Optimize-MailboxArchiveExpansion.ps1` — Automates Auto-Expanding Archive provisioning and triggers `FullCrawl` folder optimization scripts for mailboxes exceeding 90GB.
*   **`RoomMailbox/`** — Resource and calendar booking policy configurations.
    *   `Add-RoomMailboxUsers.ps1` — Reusable function to restrict room mailbox parameters and safely append authorized booking users.
*   **`SharedMailbox/`** — Access management across hybrid mail architectures.
    *   `Compare-HybridGroupMembers.ps1` — Cross-checks group memberships dynamically between on-premises Active Directory and Exchange Online.

### Root Level Scripts
*   `Get-ADUserStatus.ps1` — Active Directory query tool to quickly audit account state, email addresses, and employee details via pipeline inputs.
*   `Manage-ADMailContacts.ps1` — Streamlines localized target infrastructure contacts.
*   `Set-ADServiceAccountPassword.ps1` — Secure rotation management for domain directory service accounts.

---

## 🚀 Getting Started

### Prerequisites
Before executing these tools, ensure your management machine meets the following environment baselines:
*   Windows PowerShell 5.1 or PowerShell 7+
*   [ActiveDirectory PowerShell Module](https://learn.microsoft.com/en-us/powershell/module/activedirectory/)
*   [Exchange Online Management Module](https://learn.microsoft.com/en-us/powershell/exchange/exchange-online-powershell-v2)

### Execution Policy
Ensure your execution policy allows running downloaded scripts locally:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
