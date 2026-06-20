# Cloud-Init

This directory contains a minimal Cloud-Init example for SLES nodes.

The example is intentionally platform-neutral. Use it with Proxmox, Harvester, VMware, public cloud, or any other environment that supports Cloud-Init.

Important points:

- Set the user explicitly, for example `suse`.
- Put your SSH public key under that user.
- Avoid package upgrade during first boot unless the system is already registered and repositories are available.
- Static IP configuration is usually passed by the virtualization/cloud platform rather than this user-data file.
