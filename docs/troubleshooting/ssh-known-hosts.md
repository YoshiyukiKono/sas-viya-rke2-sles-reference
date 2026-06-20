# SSH known_hosts

If a VM is rebuilt with the same IP, SSH may report:

`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED`

Remove the stale host key:

```powershell
ssh-keygen -R <IP_ADDRESS>
```
