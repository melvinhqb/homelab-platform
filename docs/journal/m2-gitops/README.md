# M2 — GitOps

How ArgoCD and encrypted secrets were added on top of the M1 cluster: what was done at each step, what went wrong, and how it was fixed.

| # | Step | Highlights |
| --- | --- | --- |
| 1 | [ArgoCD bootstrap](01-argocd-bootstrap.md) | Trimmed upstream install, app of apps, ArgoCD managing itself, about 385 MiB of RAM |
| 2 | [Secrets with SOPS and age](02-sops-age.md) | Public key in Git, private key out of it, KSOPS in the repo server, a CI guard against clear-text Secrets |
| 3 | [When ArgoCD broke itself](03-self-management-pitfalls.md) | A kustomize older than ArgoCD's, self-heal undoing the hotfix, a mount kept alive by server-side apply |
| 4 | Full rebuild test | To do: `make destroy && make rebuild` must bring the whole platform back |

Procedures are in the [SOPS runbook](../../runbooks/sops-age.md).
