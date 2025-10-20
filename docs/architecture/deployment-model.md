# Deployment Model

> **Status:** Draft - needs content
> **Owner:** Platform Team
> **Last Updated:** 20 October 2025

## Overview

This document describes how applications and infrastructure are deployed using GitOps principles with Argo CD and Helm.

## Table of Contents

- [GitOps Principles](#gitops-principles)
- [Argo CD Architecture](#argo-cd-architecture)
- [Helm Chart Strategy](#helm-chart-strategy)
- [Sync Waves & Ordering](#sync-waves--ordering)
- [Health Checks](#health-checks)
- [Environment Strategy](#environment-strategy)
- [Rollout Strategies](#rollout-strategies)

---

## GitOps Principles

### Source of Truth

- [ ] Git is the single source of truth
- [ ] All changes via Pull Requests
- [ ] No manual `kubectl apply` in production
- [ ] Drift detection and auto-sync

### Declarative Configuration

- [ ] Kubernetes manifests
- [ ] Helm charts
- [ ] Kustomize overlays

---

## Argo CD Architecture

### App-of-Apps Pattern

```
root-app
├── 01-infrastructure
│   ├── PostgreSQL
│   ├── Redis
│   ├── NGINX Ingress
│   └── cert-manager
├── 02-observability
│   ├── Prometheus
│   ├── Loki
│   └── Tempo
├── 03-backend
└── 04-frontend
```

### Sync Policies

- [ ] Auto-sync enabled (dev/stage)
- [ ] Manual sync (production)
- [ ] Self-heal
- [ ] Prune resources

---

## Helm Chart Strategy

### Chart Structure

```
helm-charts/
├── infrastructure/
│   ├── postgresql/
│   ├── redis/
│   └── ingress-nginx/
└── application/
    ├── backend/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   ├── values-dev.yaml
    │   ├── values-prod.yaml
    │   └── templates/
    └── frontend/
```

### Values Hierarchy

1. `values.yaml` - Base values (shared)
2. `values-{env}.yaml` - Environment-specific overrides
3. Argo CD Application parameters

---

## Sync Waves & Ordering

### Wave Strategy

| Wave | Components | Reason |
|------|------------|--------|
| 0 | Namespaces, CRDs | Foundation |
| 1 | Infrastructure (DB, Redis, Ingress) | Dependencies |
| 2 | Observability (Prometheus, Loki) | Monitoring first |
| 3 | Backend Services | API layer |
| 4 | Frontend | User-facing |

### Annotations

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

---

## Health Checks

### Custom Health Checks

- [ ] StatefulSet ready replicas
- [ ] Job completion
- [ ] CRD status conditions
- [ ] Ingress TLS certificate

### Readiness Gates

```yaml
spec:
  readinessGates:
    - conditionType: "argocd.argoproj.io/health"
```

---

## Environment Strategy

### Environments

| Environment | Sync | Approval | Purpose |
|-------------|------|----------|---------|
| **dev** | Auto | None | Development testing |
| **stage** | Auto | None | Pre-production validation |
| **prod** | Manual | Required | Production workloads |

### Promotion Flow

```
dev → stage → prod
```

- Image digest promotion (not tags)
- Automated smoke tests before promotion
- Manual approval gate for production

---

## Rollout Strategies

### Rolling Update (Default)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### Blue/Green (via Ingress)

- [ ] Deploy new version (green)
- [ ] Smoke tests on green
- [ ] Switch Ingress traffic
- [ ] Monitor and rollback if needed

### Canary (Future)

- [ ] Via Argo Rollouts
- [ ] Progressive traffic shifting
- [ ] Automated analysis

---

## Disaster Recovery

### Backup

- [ ] Velero for cluster resources
- [ ] PostgreSQL PITR
- [ ] Git history as manifest backup

### Restore

1. Restore infrastructure from Git
2. Argo CD syncs all applications
3. Restore database from backup
4. Validate health checks

---

## Monitoring

### Key Metrics

- [ ] Sync status (Argo CD)
- [ ] Health status
- [ ] Drift detected
- [ ] Sync duration
- [ ] Failed syncs

### Alerts

- [ ] Argo CD sync failed
- [ ] Health degraded
- [ ] Drift detected (production)

---

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Sync Waves Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
