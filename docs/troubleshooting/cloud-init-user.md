# Cloud-Init User

If the Cloud-Init user is left as `default`, SSH public keys may be injected into the wrong user account.

Set the user explicitly to `suse` when the expected login is:

```bash
ssh suse@<ip>
```
