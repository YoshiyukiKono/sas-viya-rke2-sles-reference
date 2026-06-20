# Cloud-Init

Cloud-Init is used as a platform-neutral way to standardize initial Linux VM settings.

Recommended baseline:

- explicit `suse` user
- SSH public key for that user
- package upgrade disabled at first boot
- static IP passed by the platform or hypervisor
