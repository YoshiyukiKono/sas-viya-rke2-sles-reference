# Operations Overview

The intended flow is:

1. Provision SLES nodes using any virtualization or cloud platform.
2. Ensure SSH access using the `suse` user.
3. Copy `inventory-example.csv` to `inventory.csv`.
4. Run `Get-NodeReport.ps1` from Windows to verify node state.
5. Run Linux scripts from the jump host.
