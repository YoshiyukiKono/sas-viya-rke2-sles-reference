param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519",
    [string]$ExportPath = "/srv/nfs/viya",
    [string]$AllowedCidr = "10.110.0.0/24"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\install-nfs-server-$timestamp.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Invoke-Remote {
    param([string]$Ip, [string]$Command)

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
    foreach ($line in $output) { Write-Log "  $line" }
    return $exitCode
}


$nodes = Import-Csv $Inventory
$nfsNodes = @($nodes | Where-Object { $_.role -eq "nfs" })

if ($nfsNodes.Count -eq 0) {
    throw "No node with role=nfs found in $Inventory"
}

if ($nfsNodes.Count -ne 1) {
    throw "Expected exactly one role=nfs node, found $($nfsNodes.Count)"
}

$nfs = $nfsNodes[0]


Write-Log "Inventory   : $Inventory"
Write-Log "NFS node    : $($nfs.hostname) $($nfs.ip)"
Write-Log "Export path : $ExportPath"
Write-Log "Allowed CIDR: $AllowedCidr"
Write-Log "Log file    : $logFile"

$remoteCommand = @"
set -e

echo 'Remote hostname:'
hostname

echo 'Installing NFS server package...'
sudo zypper --non-interactive refresh
sudo zypper --non-interactive install nfs-kernel-server

echo 'Creating export directory...'
sudo mkdir -p '$ExportPath'
sudo chown nobody:nobody '$ExportPath'
sudo chmod 0777 '$ExportPath'

echo 'Configuring /etc/exports...'
EXPORT_LINE='$ExportPath $AllowedCidr(rw,sync,no_subtree_check,no_root_squash)'

if sudo grep -q "^$ExportPath " /etc/exports 2>/dev/null; then
  sudo sed -i "\#^$ExportPath #c\\$EXPORT_LINE" /etc/exports
else
  echo "$EXPORT_LINE" | sudo tee -a /etc/exports >/dev/null
fi

echo 'Reloading exports...'
sudo exportfs -ra

echo 'Starting NFS server...'
sudo systemctl enable --now nfs-server

echo 'NFS server status:'
systemctl is-active nfs-server || true

echo 'Current exports:'
sudo exportfs -v

echo 'Directory check:'
ls -ld '$ExportPath'
"@

$remoteCommand = $remoteCommand -replace "`r`n", "`n"
$remoteCommand = $remoteCommand -replace "`r", "`n"

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteCommand))
$cmd = "echo $encoded | base64 -d | bash"

Write-Log "==> Configuring NFS server: $($nfs.hostname) ($($nfs.ip))"

$exit = Invoke-Remote -Ip $nfs.ip -Command $cmd

if ($exit -ne 0) {
    Write-Log "FAILED: $($nfs.hostname) ($($nfs.ip))"
    exit $exit
}

Write-Log "OK: $($nfs.hostname) ($($nfs.ip))"