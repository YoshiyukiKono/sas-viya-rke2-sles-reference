param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519",
    [string]$RegCode = $env:SUSE_REGCODE,
    [bool]$EnablePackageHub = $true
)

if (-not (Test-Path $Inventory)) {
    throw "Inventory not found: $Inventory"
}

if ([string]::IsNullOrWhiteSpace($RegCode)) {
    throw "SUSE_REGCODE is not set. Example: `$env:SUSE_REGCODE='<your-reg-code>'"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\register-sles-$timestamp.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Invoke-Remote {
    param(
        [string]$Ip,
        [string]$Command
    )

    $target = "$User@$Ip"

    $args = @(
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=10",
        "-i", $KeyPath,
        $target,
        $Command
    )

    $output = & ssh @args 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in $output) {
        Write-Log "  $line"
    }

    return $exitCode
}

$nodes = Import-Csv $Inventory

Write-Log "Inventory: $Inventory"
Write-Log "SSH User : $User"
Write-Log "PackageHub: $EnablePackageHub"
Write-Log "Log file : $logFile"

foreach ($node in $nodes) {
    $hostname = $node.hostname
    $ip = $node.ip
    $role = $node.role

    Write-Log "==> $hostname ($ip) [$role]"

    $remoteCommand = @"
set -e

echo 'Remote hostname:'
hostname

if sudo SUSEConnect --status-text | grep -q '  Not Registered'; then
  echo 'Registering SLES'
  sudo SUSEConnect -r '$RegCode'
else
  echo 'Already registered'
fi

if [ '$EnablePackageHub' = 'True' ]; then
  if sudo SUSEConnect --list-extensions | grep -q 'SUSE Package Hub 15 SP7 x86_64 (Activated)'; then
    echo 'PackageHub already active'
  else
    echo 'Activating PackageHub'
    sudo SUSEConnect -p PackageHub/15.7/x86_64 || true
  fi
fi

sudo zypper --non-interactive refresh
"@


    $remoteCommand = $remoteCommand -replace "`r`n", "`n"
    $remoteCommand = $remoteCommand -replace "`r", "`n"

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteCommand))
    $cmd = "echo $encoded | base64 -d | bash"

    $exit = Invoke-Remote -Ip $ip -Command $cmd

    if ($exit -ne 0) {
        Write-Log "FAILED: $hostname ($ip)"
        exit $exit
    }

    Write-Log "OK: $hostname ($ip)"
}