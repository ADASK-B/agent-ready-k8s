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

### Quickstart
| Document | Purpose | Link |
|----------|---------|------|
| **Boot Routine** | After-reboot checklist, verify system operational | [`docs/quickstart/Boot-Routine.md`](../docs/quickstart/Boot-Routine.md) |
| **Setup Phase 0** | Local foundation setup, tools & components installed | [`docs/quickstart/Setup-Phase0.md`](../docs/quickstart/Setup-Phase0.md) |

### Architecture
| Document | Purpose | Link |
|----------|---------|------|
| **ARCHITECTURE** | Design decisions, golden rules, provider mapping | [`docs/architecture/ARCHITECTURE.md`](../docs/architecture/ARCHITECTURE.md) |

### Roadmap
| Document | Purpose | Link |
|----------|---------|------|
| **Phase 0** | Task list, current status | [`docs/roadmap/Phase-0.md`](../docs/roadmap/Phase-0.md) |

### Overview
| Document | Purpose | Link |
|----------|---------|------|
| **README** | Project overview, getting started | [`README.md`](../README.md) |
