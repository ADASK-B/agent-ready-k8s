# agent-ready-k8s (Claude Code)

> **WICHTIG:** Lies zuerst [`.github/copilot-instructions.md`](.github/copilot-instructions.md) für vollständiges Doc-Routing, Keywords und Dokumentationsinventar.

---

## Critical Rules

1. **English only** - All output in English (input any language)
2. **Infra decisions** → Read `docs/architecture/ARCHITECTURE.md` FIRST
3. **Before assumptions** → Check `KNOWN_ISSUES.md` (includes project analysis)

---

## Security Rules

1. **No secrets in Git** → Use `existingSecret` references
2. **Pin all images** → Never use `:latest`

---

## Current State

| Status | Component |
|--------|-----------|
| ✅ | kind, Argo CD, PostgreSQL, Redis, NGINX Ingress |
| ❌ | Backend API, Frontend, Terraform, Observability |

**Phase 0/1:** Complete | **Phase 2:** Next

**Details:** → `KNOWN_ISSUES.md` "Project Analysis" section

---

## Before Deployment

```bash
# 1. Create .env from template
cp .env.example .env
# Edit with your passwords

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
| Full doc routing | `.github/copilot-instructions.md` |
| Known issues + Analysis | `KNOWN_ISSUES.md` |
| Architecture | `docs/architecture/ARCHITECTURE.md` |
| MVP Goals | `docs/architecture/goals-and-scope.md` |
| Security | `SECURITY.md` |
| Phase status | `docs/roadmap/Phase-X.md` |
