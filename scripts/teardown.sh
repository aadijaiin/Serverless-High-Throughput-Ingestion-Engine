#!/usr/bin/env bash
# ==============================================================================
# Teardown / Destroy ResilientVote Infrastructure
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform/envs/prod"

echo "WARNING: This will permanently destroy all provisioned resources in ${TF_DIR}."
read -p "Are you sure you want to proceed? (y/N): " -r CONFIRM

if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
  cd "${TF_DIR}"
  terraform destroy -auto-approve
  echo "==> Infrastructure destroyed."
else
  echo "==> Teardown cancelled."
fi