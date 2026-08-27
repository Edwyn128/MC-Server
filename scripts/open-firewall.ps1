<#
.SYNOPSIS
    Opens inbound UDP 19132/19133 in Windows Defender Firewall for the Bedrock
    server. Run once, as Administrator. Safe/idempotent - re-running just
    confirms the rules already exist.

.NOTES
    This only affects Windows Firewall on this machine. For play over the public
    internet you ALSO need to forward those same ports on your router - see
    NETWORKING.md. This script does not touch your router.
#>

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Re-run this script from an elevated (Administrator) PowerShell prompt."
    exit 1
}

$rules = @(
    @{ Name = "Minecraft Bedrock Server (UDP 19132)"; Port = 19132 },
    @{ Name = "Minecraft Bedrock Server IPv6 (UDP 19133)"; Port = 19133 }
)

foreach ($rule in $rules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Rule already exists: $($rule.Name)" -ForegroundColor Yellow
    } else {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Protocol UDP -LocalPort $rule.Port -Action Allow | Out-Null
        Write-Host "Created inbound allow rule: $($rule.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Windows Firewall is configured. If you want players outside your home network" -ForegroundColor Cyan
Write-Host "to connect, you still need to forward these same UDP ports on your router - see NETWORKING.md."
