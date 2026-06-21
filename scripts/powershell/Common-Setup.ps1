param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519"
)

if (-not (Test-Path $Inventory)) {
    throw "Inventory not found: $Inventory"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\common-setup-$timestamp.log"

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

echo 'Refreshing repositories...'
sudo zypper --non-interactive refresh

echo 'Installing common packages...'
sudo zypper --non-interactive install \
  curl \
  wget \
  jq \
  vim \
  git-core \
  tar \
  gzip \
  unzip \
  chrony \
  qemu-guest-agent \
  nfs-client

echo 'Enabling services...'
sudo systemctl enable --now chronyd || sudo systemctl enable --now chrony || true
sudo systemctl enable --now qemu-guest-agent || true

echo 'Versions:'
curl --version | head -n 1 || true
git --version || true
jq --version || true
vim --version | head -n 1 || true

echo 'System status:'
hostnamectl
timedatectl || true
df -h /
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