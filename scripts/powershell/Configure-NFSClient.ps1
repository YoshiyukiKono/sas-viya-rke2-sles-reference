param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519",
    [string]$ExportPath = "/srv/nfs/viya",
    [string]$MountPath = "/mnt/viya-nfs"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\configure-nfs-client-$timestamp.log"

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

if ($nfsNodes.Count -ne 1) {
    throw "Expected exactly one role=nfs node, found $($nfsNodes.Count)"
}

$nfsIp = $nfsNodes[0].ip

$clientRoles = @(
    "rke2-control-plane",
    "viya-control",
    "viya-compute",
    "viya-default",
    "viya-cas",
    "viya-stateful",
    "viya-stateless"
)

$clients = @($nodes | Where-Object { $clientRoles -contains $_.role })

Write-Log "Inventory  : $Inventory"
Write-Log "NFS server : $nfsIp"
Write-Log "Export path: $ExportPath"
Write-Log "Mount path : $MountPath"
Write-Log "Log file   : $logFile"

foreach ($node in $clients) {
    $hostname = $node.hostname
    $ip = $node.ip
    $role = $node.role

    Write-Log "==> $hostname ($ip) [$role]"

    $remoteCommand = @"
set -e

echo 'Remote hostname:'
hostname

echo 'Installing NFS client package...'
sudo zypper --non-interactive install nfs-client


echo 'Checking NFS export...'
if command -v showmount >/dev/null 2>&1; then
  showmount -e $nfsIp
else
  echo 'showmount command not found; skipping export listing'
fi


echo 'Creating mount point...'
sudo mkdir -p '$MountPath'

echo 'Configuring /etc/fstab...'



FSTAB_LINE='${nfsIp}:${ExportPath} ${MountPath} nfs defaults,_netdev 0 0'

if sudo grep -q "^${nfsIp}:${ExportPath} " /etc/fstab 2>/dev/null; then
  sudo sed -i "\#^${nfsIp}:${ExportPath} #c\\$FSTAB_LINE" /etc/fstab
else
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
fi




echo 'Mounting NFS...'
sudo mount '$MountPath' || sudo mount -a

echo 'NFS mount check:'
df -h '$MountPath'

echo 'Write test:'


echo "nfs-test from `$(hostname) at `$(date)" | sudo tee "$MountPath/test-`$(hostname).txt" >/dev/null
ls -l "$MountPath/test-`$(hostname).txt"
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