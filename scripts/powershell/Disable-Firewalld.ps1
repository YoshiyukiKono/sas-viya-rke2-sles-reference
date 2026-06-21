param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\disable-firewalld-$timestamp.log"

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

Write-Log "Inventory: $Inventory"
Write-Log "Log file : $logFile"

foreach ($node in $nodes) {
    $hostname = $node.hostname
    $ip = $node.ip
    $role = $node.role

    Write-Log "==> $hostname ($ip) [$role]"

    $remoteCommand = @"
if systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
  sudo systemctl disable --now firewalld || true
  sudo systemctl mask firewalld || true
  systemctl is-active firewalld || true
else
  echo 'firewalld is not installed'
fi
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