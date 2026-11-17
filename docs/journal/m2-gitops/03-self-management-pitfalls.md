# 3. When ArgoCD broke itself

Right after the merge, `root` and `sops-check` were `Synced`, but the `argocd` application stayed `Unknown`.

## A kustomize older than ArgoCD's

- **Symptom.** ArgoCD could not render its own application: `kustomize build ... panic: runtime error: invalid memory address or nil pointer dereference`.
- **Cause.** The KSOPS integration snippet runs `ksops install --with-kustomize`, which replaces ArgoCD's kustomize (v5.8.1) with the one bundled in the KSOPS image (v5.3.0). That older version panics on the `$patch: delete` patches. `sops-check` has no such patch, so it still worked.
- **Why the checks missed it.** Local and CI checks rendered with the kustomize embedded in `kubectl` (v5.7.1), not the version running in ArgoCD.
- **Fix.** Copy only the `ksops` binary and keep ArgoCD's own kustomize. The CI now installs the same kustomize version as ArgoCD.

## Self-heal undid the hotfix

- **Symptom.** The fix, applied by hand with `make bootstrap` from the branch, worked for a few seconds. Then the repo server was back on the broken configuration.
- **Cause.** `selfHeal` did its job: the cluster must match `main`, and `main` still had the bug.
- **Fix.** Merge the fix first, then run `make bootstrap` once more. The broken repo server cannot render the commit that repairs it, so this restart has to come from the workstation. That is what `make bootstrap` is for.

## A mount kept alive by server-side apply

- **Symptom.** After that second bootstrap, the new repo server pod went into `CrashLoopBackOff`: `error mounting ... to rootfs at "/usr/local/bin/kustomize": not a directory`.
- **Cause.** With server-side apply, each field has owners. The kustomize mount was owned both by `kubectl` (the first bootstrap) and by the ArgoCD controller (the self-heal). The new apply dropped `kubectl`'s ownership, but the field stayed, owned by ArgoCD. The init container no longer created the file, so the mount had nothing to point to.
- **Fix.** Removed the stale mount once with a JSON patch, guarded by a `test` operation on its path. ArgoCD then rendered `main` and every application became `Synced` and `Healthy`. A fresh cluster does not have this history, so a rebuild is not affected.

## Lessons

- Render with the exact tool versions that run in production. "It renders on my machine" proved nothing here.
- A self-managed ArgoCD needs a way back that does not go through ArgoCD: `make bootstrap` is that way.
- Removing a field from a manifest does not remove it from the cluster when another manager still owns it. `kubectl get -o yaml --show-managed-fields` shows who owns what.
