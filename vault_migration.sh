#!/bin/bash
# ============================================================
# vault_migrate.sh
# Migrates all secrets from one Vault namespace to another
# within the same cluster.
#
# Usage:
#   ./vault_migrate.sh <vault_token> <source_namespace> <target_namespace> <secret_engine>
#
# Example:
#   ./vault_migrate.sh hvs.XXXX admin admin/new-namespace test-app
# ============================================================

set -euo pipefail

# ── Config ───────────────────────────────────────────────────
VAULT_ADDR='https://pyrc-ent-vaultcluster-public-vault-60531380.2ce29857.z1.hashicorp.cloud:8200/'
VAULT_TOKEN=''  # Passed at runtime
TEMP_FILE=$(mktemp /tmp/vault_export_XXXXXX.json)
export VAULT_ADDR VAULT_TOKEN

# ── Args ─────────────────────────────────────────────────────
if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <vault_token> <source_namespace> <target_namespace> <secret_engine>"
  echo "Example: $0 hvs.XXXX admin admin/new-namespace test-app"
  exit 1
fi

VAULT_TOKEN=$1
SOURCE_NAMESPACE=$2
TARGET_NAMESPACE=$3
SECRET_ENGINE=$4

# ── Cleanup on exit ──────────────────────────────────────────
trap 'echo "Cleaning up temp file..."; rm -f "$TEMP_FILE"' EXIT

# ── Export ───────────────────────────────────────────────────
echo "------------------------------------------------------------"
echo "Exporting from namespace : $SOURCE_NAMESPACE"
echo "Secret engine            : $SECRET_ENGINE"
echo "------------------------------------------------------------"

OUTPUT="{}"

fetch_secrets() {
  local path=$1
  local keys

  keys=$(VAULT_NAMESPACE="$SOURCE_NAMESPACE" vault kv list -format=json "$path" 2>/dev/null | jq -r '.[]') || {
    echo "  [WARN] Could not list $path — skipping"
    return
  }

  while IFS= read -r key; do
    if [[ "$key" == */ ]]; then
      fetch_secrets "$path/$key"
    else
      echo "  Fetching $path/$key..."
      data=$(VAULT_NAMESPACE="$SOURCE_NAMESPACE" vault kv get -format=json "$path/$key" | jq '.data.data')
      OUTPUT=$(echo "$OUTPUT" | jq --arg k "$path/$key" --argjson v "$data" '. + {($k): $v}')
    fi
  done <<< "$keys"
}

fetch_secrets "$SECRET_ENGINE"

echo "$OUTPUT" | jq '.' > "$TEMP_FILE"
SECRET_COUNT=$(jq 'length' "$TEMP_FILE")
echo "Export complete — $SECRET_COUNT secret(s) found."

# ── Import ───────────────────────────────────────────────────
echo ""
echo "------------------------------------------------------------"
echo "Importing into namespace : $TARGET_NAMESPACE"
echo "Secret engine            : $SECRET_ENGINE"
echo "------------------------------------------------------------"

jq -r 'to_entries[] | "\(.key)\t\(.value | tostring)"' "$TEMP_FILE" | while IFS=$'\t' read -r path data; do
  echo "  Writing $path..."
  VAULT_NAMESPACE="$TARGET_NAMESPACE" vault kv put "$path" @<(echo "$data") > /dev/null
done

echo "Import complete — $SECRET_COUNT secret(s) written."
echo "------------------------------------------------------------"