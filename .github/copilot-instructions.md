# GitHub Copilot Instructions - agent-ready-k8s

---

## 🎯 Project Goal

Build a **production-ready, AI-agent-controlled Kubernetes template** that enables:
- **Autonomous AI deployment & operations** (agent-driven GitOps)
- **Modular architecture** (composable blocks, hot-reload config)
- **Cloud-agnostic design** (local → AKS → on-prem → EKS/GKE)
- **Self-documenting structure** (AI navigates via metadata)
- **Fast iteration** (local setup <5min, automated testing)

**Why "agent-ready"?**
Traditional K8s requires manual decisions. This template provides machine-readable metadata, atomic blocks, and idempotent workflows that AI agents can execute autonomously.

---

## 🚨 Critical Rules

### PRIO 0: Language
**ALL code, docs, commits MUST be in ENGLISH.**
Input can be any language → Output always English.

### PRIO 1: Architecture
**Before ANY technical decision, read:**
[`docs/architecture/ARCHITECTURE.md`](../docs/architecture/ARCHITECTURE.md)

Contains: Golden rules, provider mapping, security policies, vendor lock-in prevention.

### PRIO 2: Maintenance
**Update this file when:**
Files/folders created, scripts changed, tech stack updated, phase completed.

---

## 📚 Documentation Registry

| Document | Purpose | Link |
|----------|---------|------|
| **Quickstart** | Boot routine, after-reboot checklist | [`docs/quickstart/Quickstart.md`](../docs/quickstart/Quickstart.md) |
| **Phase 0 Roadmap** | Complete task list, current status | [`docs/roadmap/Phase-0.md`](../docs/roadmap/Phase-0.md) |
| **Architecture** | Design decisions, golden rules | [`docs/architecture/ARCHITECTURE.md`](../docs/architecture/ARCHITECTURE.md) |
| **README** | Project overview, getting started | [`README.md`](../README.md) |
