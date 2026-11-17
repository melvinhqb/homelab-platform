# SOPS and age: encrypted secrets in Git

This repository is public. Kubernetes Secrets are committed **encrypted** with [SOPS](https://github.com/getsops/sops) and an [age](https://github.com/FiloSottile/age) key. ArgoCD decrypts them in the cluster with [KSOPS](https://github.com/viaduct-ai/kustomize-sops), a kustomize plugin added to the ArgoCD repo server.

| Item | Where it lives | In Git? |
| --- | --- | --- |
| age **public** key | `.sops.yaml` | Yes: it can only encrypt |
| age **private** key | `~/.config/sops/age/keys.txt` on the workstation, and the `sops-age` Secret in the `argocd` namespace | **Never** |
| Encrypted secrets | `*.sops.yaml` files under `platform/` | Yes |

## 1. Install the tools (workstation)

```bash
sudo apt install age

SOPS_VERSION=3.13.3
curl -fsSLO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_amd64.deb"
curl -fsSLO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt"
grep "sops_${SOPS_VERSION}_amd64.deb" "sops-v${SOPS_VERSION}.checksums.txt" | sha256sum -c -
sudo apt install "./sops_${SOPS_VERSION}_amd64.deb"
```

## 2. Create the age key (once)

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

The command prints the public key (`age1...`). Put it in `.sops.yaml`.

**Back up the private key** in a password manager. If it is lost, every encrypted secret in the repository becomes unreadable and must be recreated.

## 3. Load the key into the cluster

`make bootstrap` does it as part of a rebuild. To do it alone:

```bash
make sops-key
```

## Create or edit a secret

```bash
# Create: write the Secret in clear text, then encrypt it in place.
sops --encrypt --in-place platform/<app>/<name>.sops.yaml

# Edit: opens the decrypted file in $EDITOR and re-encrypts on save.
sops platform/<app>/<name>.sops.yaml
```

Only `data` and `stringData` are encrypted (see `.sops.yaml`), so names and namespaces stay readable in reviews.

The kustomization references the file through a KSOPS generator:

```yaml
# secret-generator.yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: <name>-generator
  annotations:
    config.kubernetes.io/function: |
      exec:
        path: ksops
files:
  - ./<name>.sops.yaml
```

```yaml
# kustomization.yaml
generators:
  - secret-generator.yaml
```

`make platform-check` (and the CI) fails if a `*.sops.yaml` file is not encrypted, or if a Secret appears in any other file.

## Use this project for your own lab

The public key in `.sops.yaml` belongs to this lab: you can encrypt with it, but not decrypt the committed secrets. They hold this lab's values anyway, so bring your own:

1. Create your own age key (step 2).
2. Replace the `age:` public key in `.sops.yaml` with yours.
3. Recreate every `*.sops.yaml` file with your own values: write the Secret in clear text, then `sops --encrypt --in-place <file>`. The existing files cannot be re-encrypted, since only their owner can decrypt them.
4. Point ArgoCD at your fork: replace the `repoURL` in `platform/root.yaml` and `platform/apps/*.yaml`.
5. Run `make bootstrap` (or `make rebuild`): it loads your private key into your cluster.

## Rotate the key

1. Create a new key (step 2) and add its public key to `.sops.yaml`, next to the old one.
2. Re-encrypt every file: `find platform -name '*.sops.yaml' -exec sops updatekeys -y {} \;`
3. Load the new key with `make sops-key`, check that ArgoCD syncs, then remove the old public key from `.sops.yaml` and run step 2 again.
4. If the old key leaked, also rotate the secrets themselves: whoever has the old key can decrypt them from the Git history.
