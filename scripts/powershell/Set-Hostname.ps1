param(
    [string]$Inventory = ".\inventory.csv",
    [string]$User = "suse",
    [string]$KeyPath = "$HOME\.ssh\id_ed25519"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = ".\set-hostname-$timestamp.log"

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

    $remoteCommand = "sudo hostnamectl set-hostname '$hostname' && hostnamectl"
    $exit = Invoke-Remote -Ip $ip -Command $remoteCommand

    if ($exit -ne 0) {
        Write-Log "FAILED: $hostname ($ip)"
        exit $exit
    }

    Write-Log "OK: $hostname ($ip)"
}