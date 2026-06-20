# sas-viya-rke2-sles-reference

Reference implementation for preparing SUSE Linux Enterprise Server (SLES) nodes for SAS Viya on RKE2.

This repository intentionally assumes that virtual machines or bare-metal hosts already exist and can be reached by SSH.
It does not include platform-specific VM provisioning procedures such as Proxmox, Harvester, VMware, or public cloud workflows.

## Scope

Included:

- Minimal inventory format
- Cloud-Init example for SLES nodes
- SLES registration workflow using SUSEConnect
- Common SLES setup
- NFS server/client setup
- RKE2 server/agent setup
- kubeconfig distribution to a jump host
- Kubernetes node labeling
- Rancher import helper
- PowerShell node report script

Excluded:

- Real IP addresses
- Registration codes
- Proxmox-specific GUI operations
- Private lab journals
- Customer- or company-specific secrets

## Inventory

Copy the example inventory and edit it for your environment.

```bash
cp inventory-example.csv inventory.csv
```

The inventory format is intentionally small:

```csv
hostname,ip,role
jump-host,10.0.0.189,jump
nfs,10.0.0.190,nfs
rke2-control-plane,10.0.0.191,rke2-control-plane
```

## First verification from Windows

Run the node report from PowerShell:

```powershell
.\scripts\powershell\Get-NodeReport.ps1 -Inventory .\inventory.csv
```

By default, it writes a timestamped CSV report to the current working directory.

## Linux workflow from the jump host

Linux scripts are intended to be run from the jump host.

```bash
./scripts/linux/01-register-sles.sh inventory.csv
./scripts/linux/02-common-setup.sh inventory.csv
./scripts/linux/03-nfs-server.sh inventory.csv
./scripts/linux/04-nfs-client.sh inventory.csv
./scripts/linux/05-rke2-server.sh inventory.csv
./scripts/linux/06-rke2-agent.sh inventory.csv
./scripts/linux/07-kubeconfig-to-jump.sh inventory.csv
./scripts/linux/08-node-labels.sh inventory.csv
./scripts/linux/09-viya-prereq-check.sh inventory.csv
```

Each Linux script writes a timestamped log file to the current working directory.

## Local execution outputs

The repository ignores local inventory files, logs, and reports:

- `inventory.csv`
- `*.log`
- `node-report-*.csv`
