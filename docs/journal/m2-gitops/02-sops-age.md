# 2. Secrets with SOPS and age

## Goal

Commit Kubernetes Secrets to a public repository without exposing them, and let ArgoCD deploy them like any other manifest.

## What was done

- **An age key pair on the workstation.** The private key stays in `~/.config/sops/age/keys.txt` (and a password manager). The public key goes into `.sops.yaml`: it can only encrypt.
- **Values only.** `.sops.yaml` encrypts `data` and `stringData`. Names, namespaces and types stay readable, so pull requests can still be reviewed.
- **KSOPS in the repo server.** An init container copies the `ksops` binary into the repo server, and `kustomize.buildOptions` enables exec plugins. The private key reaches the cluster only through `make sops-key`, as the `sops-age` Secret, mounted read-only.
- **A smoke test.** `platform/sops-check/` deploys one encrypted Secret. Once synced, it reads `decrypted by KSOPS in the ArgoCD repo server` in the cluster.
- **A CI guard.** `scripts/check-platform.sh` fails when a Secret appears outside a `*.sops.yaml` file, or when a `*.sops.yaml` file is not encrypted.

## Checks

Before the merge, the chain was tested inside the repo server itself: clone the branch, then run the same build as ArgoCD.

```bash
kubectl -n argocd exec deploy/argocd-repo-server -- sh -c \
  'git clone -q --depth 1 -b <branch> <repo> /tmp/m2 &&
   kustomize build --enable-alpha-plugins --enable-exec /tmp/m2/platform/sops-check'
```

After the merge:

```bash
kubectl -n sops-check get secret sops-check -o jsonpath='{.data.message}' | base64 -d
# decrypted by KSOPS in the ArgoCD repo server
```

## Lessons

- A public key in a public repository is the point, not a leak. Someone reusing the project brings their own key and recreates the secrets with their own values (see the [runbook](../../runbooks/sops-age.md#use-this-project-for-your-own-lab)).
- The private key has to be backed up outside the workstation: losing it makes every committed secret unreadable.
