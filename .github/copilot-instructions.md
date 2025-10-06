# GitHub Copilot Instructions - agent-ready-k8s

> **🎯 Purpose:** AI Navigation Wiki - Metadata registry for project structure  
> **⚠️ CRITICAL:** Update this file with every structural change!  
> **📚 Strategy:** Metadata here → Details in `/docs/` → Code in `/setup-template/`

---

## 🚨 MANDATORY READING FOR AI AGENTS

**Before making ANY architectural or technical decision, you MUST read:**

📖 **[`/docs/architecture/ARCHITECTURE.md`](/docs/architecture/ARCHITECTURE.md)**

This file contains:
- **Golden Rules** for cloud-agnostic design
- **Do's & Don'ts** by domain (Terraform, GitOps, Networking, Security, etc.)
- **Provider mapping** (AKS vs. On-Prem vs. EKS vs. GKE)
- **Decision criteria** for tool selection

**Why mandatory?**
- Ensures consistency across Phase 1 (local) → Phase 2 (AKS/On-Prem)
- Prevents vendor lock-in patterns
- Enforces security & portability by design

**When to read it:**
- ✅ Before suggesting infrastructure changes
- ✅ Before adding new dependencies/tools
- ✅ Before modifying GitOps structure
- ✅ Before making security-related decisions
- ✅ When choosing between implementation alternatives

---

## 🌍 PRIO 0: LANGUAGE RULE

**🚨 ALL CODE, DOCS, AND COMMITS MUST BE IN ENGLISH! 🚨**

- ✅ Input: Any language (German, English, etc.)
- ✅ Output: **ALWAYS ENGLISH**
- ✅ Files: **ENGLISH ONLY**
- ✅ Commits: **ENGLISH ONLY**
- ✅ Comments: **ENGLISH ONLY**

---

## ⚠️ PRIO 1: MAINTENANCE DUTY

**Update this file when:**
- ✅ New files/folders created
- ✅ Scripts/commands changed
- ✅ Documentation structure modified
- ✅ Tech stack updated
- ✅ Project status changed

**Why:** AI reads this first for navigation and decision-making.

---

## 📖 Project Overview

**Name:** agent-ready-k8s  
**Type:** AI-Driven Kubernetes Template Stack  
**Current Status:** 🏗️ **IN DEVELOPMENT**  
**Architecture:** 2-Phase (Local → Cloud)

**🎯 Project Goal:**
Build a **scalable, AI-agent-friendly Kubernetes template** that can be:
- 🤖 **Controlled by AI agents** (automated decision-making)
- 📦 **Modular & composable** (blocks can be combined/extended)
- 🚀 **Fast to deploy** (local in ~1 min, production-ready structure)
- 🔄 **GitOps-native** (git as single source of truth)
- 📚 **Self-documenting** (AI can navigate via metadata)

**Why "agent-ready"?**
Traditional K8s setups require manual decisions. This template provides:
- Clear metadata for AI navigation (this file)
- Atomic, testable blocks (phase1/XX-name/)
- Declarative structure (AI knows what to change)
- Automated workflows (AI can trigger deployments)

**Phases:**
1. **Local Dev** - kind cluster + demo app (~1 min setup)
2. **Cloud Deploy** - Argo CD GitOps + Azure AKS (planned)

**Target Users:**
- 🤖 AI agents automating infrastructure
- 👨‍💻 Developers needing quick local K8s
- 🏢 Teams seeking production-ready templates
- 🎓 K8s + GitOps learners

---

## 🗂️ File Registry (AI Navigation)

### **Core Documentation**

| File | Location | Purpose | Status |
|------|----------|---------|--------|
| **⚠️ Architecture** | `/docs/architecture/ARCHITECTURE.md` | **MANDATORY:** Design principles, golden rules, decision criteria | 📝 To be filled |
| **README** | `/README.md` | Project overview, quick start | 📝 Core |
| **Roadmap** | `/ROADMAP.md` | Phase checklists, progress tracking | ✅ Active |
| **Quickstart** | `/docs/quickstart/Quickstart.md` | Setup guide, troubleshooting | 🔄 In Progress |
| **System Overview** | `/docs/SYSTEM_OVERVIEW.md` | Architecture diagrams, design decisions | 📋 Planned |
| **This File** | `/.github/copilot-instructions.md` | Metadata registry, AI navigation | ✅ Active |

### **Code & Scripts**

| Path | Purpose | Phase |
|------|---------|-------|
| `/setup-template/` | Automation scripts | All |
| `/setup-template/setup-phase1.sh` | Phase 1 orchestrator | 1 |
| `/setup-template/phase1/` | Phase 1 setup blocks (6 blocks) | 1 |
| `/setup-template/phase2/` | Phase 2 setup blocks | 2 (planned) |
| `/docs/` | Documentation files | All |
| `.gitignore` | Git exclusions | All |
| `LICENSE` | MIT License | All |

### **Project Structure Notes**

- **Development Phase:** Structure evolves between Phase 1 and Phase 2
- **Generated Files:** Created during setup (see `.gitignore` for excluded paths)
- **Phase 1 Focus:** Local development (kind, Helm, manifests)
- **Phase 2 Changes:** Will add GitOps structure (Argo CD, AKS configs)

**⚠️ Note:** Specific folder structure depends on current phase. Check `ROADMAP.md` for phase status.

---

## 🛠️ Tech Stack

### **Phase 1 - Local Development**
| Component | Purpose | Status |
|-----------|---------|--------|
| **Docker** | Container runtime | Required |
| **kind** | Local Kubernetes clusters | Required |
| **kubectl** | Kubernetes CLI | Required |
| **Helm** | Package manager | Required |
| **Argo CD CLI** | GitOps tool (for Phase 2) | Optional |
| **Task** | Task runner | Optional |

### **Phase 2 - Cloud (Planned)**
| Component | Purpose | Status |
|-----------|---------|--------|
| **Argo CD** | GitOps continuous delivery | 📋 Planned |
| **Azure AKS** | Managed Kubernetes | 📋 Planned |
| **cert-manager** | TLS certificate automation | 📋 Planned |
| **Sealed Secrets** | Encrypted secret management | 📋 Planned |
| **GitHub Actions** | CI/CD pipeline | 📋 Planned |

**Version Info:** See individual setup scripts in `/setup-template/phase1/` for specific version requirements.

---

## 🚀 Command Reference

### **Phase 1 - Quick Start**
```bash
# Complete automated setup
./setup-template/setup-phase1.sh

# Test individual blocks
./setup-template/phase1/*/test.sh
```

### **Common Operations**
```bash
# Check status
kubectl get pods -A
kind get clusters

# Cleanup
kind delete cluster --name agent-k8s-local
```

**More Commands:** See `ROADMAP.md` for phase-specific commands and workflows.

---

## 📊 Current Status

**Development Phase:** Check `ROADMAP.md` for current progress  
**Active Work:** See latest commits and open issues  
**Last Updated:** 06.01.2025

---

## 🎯 AI Quick Reference

**For setup questions:** → Read `/docs/quickstart/Quickstart.md`  
**For project overview:** → Read `/README.md`  
**For implementation details:** → Read `/ROADMAP.md`  
**For code execution:** → Run scripts in `/setup-template/`  
**For structure changes:** → **Update this file first!**

---