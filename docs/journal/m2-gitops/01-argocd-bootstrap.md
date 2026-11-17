# 1. ArgoCD bootstrap

## Goal

End `make rebuild` with a cluster that deploys itself from Git: after the bootstrap, no more `kubectl apply` by hand.

## What was done

- **Upstream manifest, pinned.** `platform/argocd/kustomization.yaml` pulls the official `install.yaml` of ArgoCD 3.5.7. The version lives in that one URL.
- **Trimmed install.** Dex, the notifications controller and the ApplicationSet controller are removed with `$patch: delete` patches. Four components remain: the API server and UI, the repo server, the application controller and Redis.
- **App of apps.** `platform/root.yaml` is the only manifest applied by hand (by `make bootstrap`). It syncs `platform/apps/`, where each component is one `Application`.
- **ArgoCD manages itself.** `platform/apps/argocd.yaml` points back at `platform/argocd`, with `selfHeal` on and `prune` off, so a bad commit cannot delete ArgoCD. `ServerSideApply` is required: the ArgoCD CRDs are too large for client-side apply.
- **`make bootstrap`.** Creates the namespace, loads the age key, applies the install, waits for the repo server and API server, then applies the root app. It is idempotent and now ends `make rebuild`.

## Results

| Component | Memory after warm-up |
| --- | --- |
| `argocd-application-controller` | 292 MiB |
| `argocd-repo-server` | 53 MiB |
| `argocd-server` | 31 MiB |
| `argocd-redis` | 9 MiB |
| **Total** | **about 385 MiB** |

Right on the 400 MiB planned in the [resource budget](../../../README.md#resource-budget). All pods were scheduled on `k3s-agent-1`.

## Lessons

- The root app reads `main`: until the pull request is merged, it reports `app path does not exist`. That is expected, not a failure.
- `k3s-server-1` already uses about 65 % of its 2 GiB with only the control plane and system pods. Workloads should stay off it (to do in M3).
