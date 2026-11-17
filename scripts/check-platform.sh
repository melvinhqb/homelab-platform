#!/usr/bin/env bash
# Checks run on platform/ and apps/ by the CI (and by `make platform-check`).
#  1. Every kustomization renders (except those that need KSOPS to decrypt).
#  2. No Secret is committed in clear text: Secrets only live in *.sops.yaml
#     files, and each of those must actually be encrypted by SOPS.
set -euo pipefail

cd "$(dirname "$0")/.."
status=0

# Render with the same kustomize version as ArgoCD (the CI installs it).
# kubectl's embedded kustomize can differ and hide version-specific bugs.
if command -v kustomize > /dev/null; then
  render() { kustomize build "$1"; }
  echo "Using $(kustomize version)"
else
  render() { kubectl kustomize "$1"; }
  echo "kustomize not found: falling back to kubectl kustomize (may differ from ArgoCD)"
fi

echo "==> Rendering kustomizations"
while IFS= read -r k; do
  dir=$(dirname "$k")
  if grep -rqs "kind: ksops" "$dir"; then
    echo "skip  $dir (needs KSOPS and the age key)"
    continue
  fi
  if render "$dir" > /dev/null; then
    echo "ok    $dir"
  else
    echo "FAIL  $dir"; status=1
  fi
done < <(find platform apps -name kustomization.yaml | sort)

echo "==> Looking for clear-text Secrets"
while IFS= read -r f; do
  case "$f" in
    *.sops.yaml)
      if ! grep -q "^sops:" "$f" || ! grep -q "ENC\[" "$f"; then
        echo "FAIL  $f is named *.sops.yaml but is not encrypted"; status=1
      fi ;;
    *)
      if grep -qE "^kind: Secret$" "$f"; then
        echo "FAIL  $f contains a Secret: encrypt it with SOPS (*.sops.yaml)"; status=1
      fi ;;
  esac
done < <(find platform apps -name "*.yaml" | sort)

[ "$status" -eq 0 ] && echo "All platform checks passed."
exit "$status"
