# agent-ready-k8s (Claude Code Instructions)

> **START HERE:** This file is the primary entry point for all AI agents.
>
> For detailed documentation routing and keyword matching, see [`.github/copilot-instructions.md`](.github/copilot-instructions.md) after reading this file.

---

## Document Hierarchy

```
1. CLAUDE.md (this file)     ← Read FIRST (critical rules + quick start)
2. copilot-instructions.md   ← Read SECOND (detailed routing logic)
3. Specific docs             ← Read on-demand (based on routing)
```

---

## Critical Rules

1. **English only** - All output in English (input may be any language)
2. **Infra decisions** → Read `docs/architecture/ARCHITECTURE.md` FIRST
3. **Before assumptions** → Check `KNOWN_ISSUES.md` (includes project analysis)

---

## Security Rules

1. **No secrets in Git** → Use `existingSecret` references only
2. **Pin all images** → Never use `:latest` tag

---

## Current Implementation Status

**What's actually deployed (Phase 0/1 complete):**
- ✅ kind cluster (1.30.2)
- ✅ Argo CD (v2.12.3)
- ✅ PostgreSQL 16.4.0 (Bitnami Helm chart)
- ✅ Redis 7.4.1 (Bitnami Helm chart)
- ✅ NGINX Ingress (vendored)
- ✅ podinfo demo app (removal planned Phase 2a)

**What's NOT yet implemented (planned):**
- ❌ Backend API (FastAPI) → Phase 2a (next)
- ❌ Frontend (React/Vue) → Phase 5+
- ❌ Observability stack → Phase 3
- ❌ Terraform modules → Phase 4
- ❌ Kyverno/OPA policies → Phase 5+

**Current Phase:** Phase 2 (Backend API)

**Full gap analysis:** → `KNOWN_ISSUES.md` section "Project Analysis"

---

## Before Deployment

```bash
# 0. Create namespace if not exists
kubectl create namespace demo-platform --dry-run=client -o yaml | kubectl apply -f -

# 1. Create .env from template
cp .env.example .env
# Edit with your passwords (POSTGRES_PASSWORD, POSTGRES_USER_PASSWORD, REDIS_PASSWORD)

# 2. Create K8s secrets
source .env
kubectl create secret generic postgresql-credentials \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=password=$POSTGRES_USER_PASSWORD \
  -n demo-platform

kubectl create secret generic redis-credentials \
  --from-literal=redis-password=$REDIS_PASSWORD \
  -n demo-platform
```

---

## Quick Reference

| Need | File |
|------|------|
| Detailed routing logic | `.github/copilot-instructions.md` |
| Known issues + Gap analysis | `KNOWN_ISSUES.md` |
| Architecture decisions | `docs/architecture/ARCHITECTURE.md` |
| MVP Goals & Scope | `docs/architecture/goals-and-scope.md` |
| Security policy | `SECURITY.md` |
| Phase 0 status | `docs/roadmap/Phase-0.md` |
| Phase 1 status | `docs/roadmap/Phase-1.md` |
| Phase 2 (current) | `docs/roadmap/Phase-2.md` |
