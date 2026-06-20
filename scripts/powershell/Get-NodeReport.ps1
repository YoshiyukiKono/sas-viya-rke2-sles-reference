<#
.SYNOPSIS
  Collects a basic node report over SSH.

.DESCRIPTION
  Reads an inventory CSV with the columns:
    hostname,ip,role

  For each enabled row, this script tries to SSH to the node and collect:
    - SSH reachability
    - remote hostname
    - OS release
    - kernel
    - CPU count
    - memory
    - root filesystem size
    - uptime
    - qemu-guest-agent package hint

  By default, output is written to:
    node-report-yyyyMMdd-HHmmss.csv

.EXAMPLE
  .\scripts\powershell\Get-NodeReport.ps1 -Inventory .\inventory.csv

.EXAMPLE
  .\scripts\powershell\Get-NodeReport.ps1 -Inventory .\inventory.csv -User suse -KeyPath $HOME\.ssh\id_ed25519
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Inventory = ".\inventory.csv",

    [Parameter(Mandatory = $false)]
    [string]$User = "suse",

    [Parameter(Mandatory = $false)]
    [string]$KeyPath = "$HOME\.ssh\id_ed25519",

    [Parameter(Mandatory = $false)]
    [int]$ConnectTimeoutSeconds = 5,

    [Parameter(Mandatory = $false)]
    [string]$Output
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Timestamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Resolve-OutputPath {
    param([string]$ExplicitOutput)

    if ([string]::IsNullOrWhiteSpace($ExplicitOutput)) {
        return ".\node-report-$(New-Timestamp).csv"
    }

    return $ExplicitOutput
}

function Test-CommandAvailable {
    param([string]$Command)

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

function Invoke-SshCommand {
    param(
        [string]$Target,
        [string]$Command,
        [string]$KeyPath,
        [int]$Timeout
    )

    $sshArgs = @(
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=$Timeout",
        "-i", $KeyPath,
        $Target,
        $Command
    )

    $output = & ssh @sshArgs 2>&1
    $exitCode = $LASTEXITCODE

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = ($output -join "`n")
    }
}

function Convert-RemoteKvOutput {
    param([string]$Text)

    $hash = @{}
    foreach ($line in ($Text -split "`n")) {
        if ($line -match "^\s*([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            $hash[$key] = $val
        }
    }

    return $hash
}

if (-not (Test-Path $Inventory)) {
    throw "Inventory file not found: $Inventory"
}

if (-not (Test-CommandAvailable "ssh")) {
    throw "ssh command not found. Install or enable OpenSSH Client on Windows."
}

if (-not (Test-Path $KeyPath)) {
    Write-Warning "SSH key not found: $KeyPath. SSH may fail unless another key is available."
}

$outputPath = Resolve-OutputPath -ExplicitOutput $Output
$nodes = Import-Csv -Path $Inventory

$remoteScript = @'
echo expected_probe=ok
echo remote_hostname=$(hostname 2>/dev/null || echo unknown)
echo os_pretty=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo unknown)
echo kernel=$(uname -r 2>/dev/null || echo unknown)
echo cpu_count=$(nproc 2>/dev/null || echo unknown)
echo memory_total_mb=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo unknown)
echo root_fs=$(df -h / 2>/dev/null | awk 'NR==2 {print $2}' || echo unknown)
echo root_fs_used=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo unknown)
echo uptime=$(uptime -p 2>/dev/null | sed 's/^up //' || echo unknown)
if command -v rpm >/dev/null 2>&1; then
  if rpm -q qemu-guest-agent >/dev/null 2>&1; then
    echo qemu_guest_agent=installed
  else
    echo qemu_guest_agent=not-installed
  fi
else
  echo qemu_guest_agent=unknown
fi
'@

$results = New-Object System.Collections.Generic.List[object]

foreach ($node in $nodes) {
    if ($node.PSObject.Properties.Name -contains "enabled") {
        if ($node.enabled -and $node.enabled.ToString().ToLowerInvariant() -eq "false") {
            continue
        }
    }

    $hostname = $node.hostname
    $ip = $node.ip
    $role = $node.role
    $target = "$User@$ip"

    Write-Host "Checking $hostname ($ip) [$role]..."

    $row = [ordered]@{
        expected_hostname = $hostname
        ip                = $ip
        role              = $role
        ssh               = "FAIL"
        remote_hostname   = ""
        hostname_match    = ""
        os                = ""
        kernel            = ""
        cpu_count         = ""
        memory_total_mb   = ""
        root_fs           = ""
        root_fs_used      = ""
        uptime            = ""
        qemu_guest_agent  = ""
        error             = ""
    }

    try {
        $cmd = "bash -lc " + "'" + $remoteScript.Replace("'", "'\''") + "'"
        $sshResult = Invoke-SshCommand -Target $target -Command $cmd -KeyPath $KeyPath -Timeout $ConnectTimeoutSeconds

        if ($sshResult.ExitCode -eq 0) {
            $kv = Convert-RemoteKvOutput -Text $sshResult.Output

            $row.ssh              = "OK"
            $row.remote_hostname  = $kv["remote_hostname"]
            $row.hostname_match   = if ($kv["remote_hostname"] -eq $hostname) { "OK" } else { "MISMATCH" }
            $row.os               = $kv["os_pretty"]
            $row.kernel           = $kv["kernel"]
            $row.cpu_count        = $kv["cpu_count"]
            $row.memory_total_mb  = $kv["memory_total_mb"]
            $row.root_fs          = $kv["root_fs"]
            $row.root_fs_used     = $kv["root_fs_used"]
            $row.uptime           = $kv["uptime"]
            $row.qemu_guest_agent = $kv["qemu_guest_agent"]
        }
        else {
            $row.error = $sshResult.Output
        }
    }
    catch {
        $row.error = $_.Exception.Message
    }

    $results.Add([PSCustomObject]$row)
}

$results | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Report written: $outputPath"
Write-Host ""

$results | Format-Table expected_hostname, ip, role, ssh, remote_hostname, hostname_match, cpu_count, memory_total_mb, root_fs -AutoSize
