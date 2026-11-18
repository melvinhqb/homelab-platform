# 4. Full rebuild test

The M2 promise: `make destroy && make rebuild` brings the whole platform back, with no manual step after the command. Shortlink and its PostgreSQL had just been merged into `platform/apps/`, so the test covered a real application with an encrypted secret, not only the platform.

## Run

```bash
make destroy && make rebuild
```

What came back, read from the creation timestamps of the new objects:

| Time (UTC) | Event |
| --- | --- |
| 10:14:00 | `k3s-server-1` registered |
| 10:14:10 | `k3s-agent-1` registered |
| 10:15:10 | `root` application created by `make bootstrap` |
| 10:15:13 | `argocd`, `sops-check` and `shortlink` created by `root` |

About 70 seconds after the first node registered, the four applications were `Synced` and `Healthy`.

## Checks

- Both nodes `Ready`. `make rebuild` checks this itself.
- `argocd`, `root`, `sops-check` and `shortlink`: `Synced` and `Healthy`.
- Shortlink answers `{"status":"UP"}` on `/actuator/health` through a port-forward. This is the end-to-end check for secrets: the app only starts if KSOPS decrypted the database password and PostgreSQL accepted it.

## What changes on every rebuild

These are expected, but they surprised the first time:

- **The ArgoCD admin password.** `argocd-initial-admin-secret` is regenerated at install. `make argocd-ui` prints the new one.
- **The ArgoCD TLS certificate.** It is self-signed and regenerated too. A browser that had accepted the old one rejects the new one and resets its connections in a loop; the port-forward then prints `connection reset by peer` errors on the local side. Accepting the new certificate, or using a private window, fixes it.
- **The PostgreSQL data.** The volume goes away with the VMs. Acceptable while the database holds test data only; tested backups and restore are the M6 scope.

## Lessons

- A rebuild test is only meaningful with something stateful and secret on board. Shortlink proved that the age key, KSOPS and the app of apps work together from zero.
- "Everything is rebuilt" includes credentials and certificates. Nothing should depend on values from a previous cluster.
