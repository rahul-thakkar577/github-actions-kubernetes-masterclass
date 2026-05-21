#!/bin/bash
# ============================================================
# SkillPulse MySQL Backup Script
# Usage: ./backup-mysql.sh [dev|staging|production]
# Cron:  0 2 * * * /scripts/backup-mysql.sh production
# ============================================================

set -euo pipefail

# ---- Config ------------------------------------------------
NAMESPACE="${1:-production}"
BACKUP_DIR="/backups/mysql"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${NAMESPACE}_skillpulse_${TIMESTAMP}.sql.gz"

# ---- Colors ------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn()   { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error()  { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; exit 1; }

# ---- Validate Namespace ------------------------------------
if [[ ! "$NAMESPACE" =~ ^(dev|staging|production)$ ]]; then
  error "Invalid namespace. Use: dev | staging | production"
fi

log "Starting MySQL backup for namespace: $NAMESPACE"

# ---- Create backup directory ------------------------------
mkdir -p "$BACKUP_DIR"

# ---- Get MySQL pod name -----------------------------------
MYSQL_POD=$(kubectl get pod -n "$NAMESPACE" -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || \
  error "No MySQL pod found in namespace: $NAMESPACE"

log "Found MySQL pod: $MYSQL_POD"

# ---- Get DB credentials from secret ----------------------
DB_USER=$(kubectl get secret skillpulse-db -n "$NAMESPACE" \
  -o jsonpath='{.data.MYSQL_USER}' | base64 -d)
DB_PASS=$(kubectl get secret skillpulse-db -n "$NAMESPACE" \
  -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d)
DB_NAME=$(kubectl get secret skillpulse-db -n "$NAMESPACE" \
  -o jsonpath='{.data.MYSQL_DATABASE}' | base64 -d)

log "Credentials loaded from secret"

# ---- Run mysqldump inside pod ----------------------------
log "Dumping database: $DB_NAME → $BACKUP_FILE"
kubectl exec -n "$NAMESPACE" "$MYSQL_POD" -- \
  mysqldump -u"$DB_USER" -p"$DB_PASS" \
  --single-transaction \
  --routines \
  --triggers \
  "$DB_NAME" | gzip > "$BACKUP_FILE"

# ---- Verify backup size ----------------------------------
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
log "Backup complete! Size: $BACKUP_SIZE → $BACKUP_FILE"

# ---- Cleanup old backups ---------------------------------
log "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "${NAMESPACE}_skillpulse_*.sql.gz" \
  -mtime +${RETENTION_DAYS} -delete
REMAINING=$(find "$BACKUP_DIR" -name "${NAMESPACE}_skillpulse_*.sql.gz" | wc -l)
log "Retention cleanup done. Remaining backups: $REMAINING"

log "MySQL backup finished successfully 🎉"
