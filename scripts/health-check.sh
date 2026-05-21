#!/bin/bash
# ============================================================
# SkillPulse Health Check Script
# Usage: ./health-check.sh [dev|staging|production|all]
# ============================================================

set -euo pipefail

TARGET="${1:-all}"
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${GREEN}✅ $1${NC}"; }
error()  { echo -e "${RED}❌ $1${NC}"; }
info()   { echo -e "${BLUE}🔍 $1${NC}"; }
section(){ echo -e "\n${YELLOW}══════════════════════════════════${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${YELLOW}══════════════════════════════════${NC}"; }

FAILED=0

check_namespace() {
  local NS=$1
  section "Checking: $NS"

  # Check pods
  info "Pod Status:"
  PODS=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null)
  if [[ -z "$PODS" ]]; then
    error "No pods found in $NS"
    FAILED=$((FAILED+1))
    return
  fi
  echo "$PODS"

  # Count not-running pods
  NOT_RUNNING=$(echo "$PODS" | grep -v "Running\|Completed" | wc -l)
  if [[ $NOT_RUNNING -gt 0 ]]; then
    error "$NOT_RUNNING pod(s) not in Running state in $NS"
    FAILED=$((FAILED+1))
  else
    log "All pods running in $NS"
  fi

  # Check deployments rollout
  info "Deployment Rollout:"
  kubectl rollout status deployment/backend -n "$NS" --timeout=30s && \
    log "Backend deployment healthy" || { error "Backend deployment not ready"; FAILED=$((FAILED+1)); }
  kubectl rollout status deployment/frontend -n "$NS" --timeout=30s && \
    log "Frontend deployment healthy" || { error "Frontend deployment not ready"; FAILED=$((FAILED+1)); }

  # Check MySQL
  info "MySQL StatefulSet:"
  MYSQL_READY=$(kubectl get statefulset mysql -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "$MYSQL_READY" == "1" ]]; then
    log "MySQL is ready"
  else
    error "MySQL not ready (readyReplicas: $MYSQL_READY)"
    FAILED=$((FAILED+1))
  fi
}

if [[ "$TARGET" == "all" ]]; then
  for NS in dev staging production; do
    kubectl get namespace "$NS" &>/dev/null && check_namespace "$NS" || info "Namespace $NS not found, skipping"
  done
else
  check_namespace "$TARGET"
fi

section "Summary"
if [[ $FAILED -eq 0 ]]; then
  log "All checks passed! 🎉"
else
  error "$FAILED check(s) failed!"
  exit 1
fi
