#!/bin/bash
# ============================================================
# SkillPulse Full Deploy Script
# Usage: ./scripts/deploy.sh
# Deploys: App + Monitoring to KinD cluster
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
error()  { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; exit 1; }
info()   { echo -e "${YELLOW}[$(date +'%H:%M:%S')] 🔄 $1${NC}"; }

# Set kubectl context
kubectl config use-context kind-skillpulse

info "Deploying SkillPulse app..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/10-mysql.yaml
kubectl apply -f k8s/20-backend.yaml
kubectl apply -f k8s/30-frontend.yaml
log "App manifests applied!"

info "Waiting for MySQL..."
kubectl rollout status statefulset/mysql -n skillpulse --timeout=180s
log "MySQL ready!"

info "Waiting for Backend..."
kubectl rollout status deployment/backend -n skillpulse --timeout=120s
log "Backend ready!"

info "Waiting for Frontend..."
kubectl rollout status deployment/frontend -n skillpulse --timeout=120s
log "Frontend ready!"

info "Deploying Monitoring stack..."
kubectl apply -f monitoring/monitoring.yaml
log "Monitoring applied!"

info "Waiting for Prometheus..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s
log "Prometheus ready!"

info "Waiting for Grafana..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s
log "Grafana ready!"

echo ""
log "🎉 Full deployment complete!"
echo ""
echo -e "${GREEN}App URLs:${NC}"
echo -e "  Frontend:   http://localhost:8888"
echo -e "  Prometheus: http://localhost:9090"
echo -e "  Grafana:    http://localhost:3000  (admin/admin123)"
echo ""
echo -e "${YELLOW}Port-forward commands (if needed):${NC}"
echo -e "  kubectl port-forward svc/frontend -n skillpulse 8888:80"
echo -e "  kubectl port-forward svc/prometheus -n monitoring 9090:9090"
echo -e "  kubectl port-forward svc/grafana -n monitoring 3000:3000"
