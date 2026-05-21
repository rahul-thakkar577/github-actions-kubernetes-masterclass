#!/bin/bash
# ============================================================
# SkillPulse Cleanup Script
# Cleans up completed/failed pods and old replicasets
# Usage: ./cleanup.sh [dry-run]
# ============================================================

set -euo pipefail

DRY_RUN="${1:-}"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${YELLOW}🔍 $1${NC}"; }

if [[ "$DRY_RUN" == "dry-run" ]]; then
  info "DRY RUN MODE - no changes will be made"
  CMD="echo Would run:"
else
  CMD=""
fi

for NS in dev staging production; do
  kubectl get namespace "$NS" &>/dev/null || continue
  info "Cleaning namespace: $NS"

  # Delete completed pods
  COMPLETED=$(kubectl get pods -n "$NS" --field-selector=status.phase=Succeeded \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [[ -n "$COMPLETED" ]]; then
    $CMD kubectl delete pod -n "$NS" $COMPLETED
    log "Deleted completed pods in $NS"
  fi

  # Delete failed pods
  FAILED=$(kubectl get pods -n "$NS" --field-selector=status.phase=Failed \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [[ -n "$FAILED" ]]; then
    $CMD kubectl delete pod -n "$NS" $FAILED
    log "Deleted failed pods in $NS"
  fi
done

log "Cleanup complete!"
