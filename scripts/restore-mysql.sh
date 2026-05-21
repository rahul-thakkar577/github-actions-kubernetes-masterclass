#!/bin/bash
# ============================================================
# SkillPulse MySQL Restore Script
# Usage: ./restore-mysql.sh [dev|staging|production] <backup_file.sql.gz>
# ============================================================

set -euo pipefail

NAMESPACE="${1:-}"
BACKUP_FILE="${2:-}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; exit 1; }

[[ -z "$NAMESPACE" ]] && error "Usage: $0 [dev|staging|production] <backup.sql.gz>"
[[ -z "$BACKUP_FILE" ]] && error "Usage: $0 [dev|staging|production] <backup.sql.gz>"
[[ ! -f "$BACKUP_FILE" ]] && error "Backup file not found: $BACKUP_FILE"

# Production safety gate
if [[ "$NAMESPACE" == "production" ]]; then
  warn "⚠️  You are restoring to PRODUCTION!"
  read -p "Type 'yes-i-am-sure' to continue: " CONFIRM
  [[ "$CONFIRM" != "yes-i-am-sure" ]] && error "Restore cancelled"
fi

MYSQL_POD=$(kubectl get pod -n "$NAMESPACE" -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}') || error "MySQL pod not found"

DB_USER=$(kubectl get secret skillpulse-db -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_USER}' | base64 -d)
DB_PASS=$(kubectl get secret skillpulse-db -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d)
DB_NAME=$(kubectl get secret skillpulse-db -n "$NAMESPACE" -o jsonpath='{.data.MYSQL_DATABASE}' | base64 -d)

log "Restoring $BACKUP_FILE → $DB_NAME in $NAMESPACE"
gunzip -c "$BACKUP_FILE" | kubectl exec -i -n "$NAMESPACE" "$MYSQL_POD" -- \
  mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME"

log "Restore complete! ✅"
