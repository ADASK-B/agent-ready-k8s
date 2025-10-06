# GitHub Copilot Instructions - agent-ready-k8s

> **🎯 Purpose:** AI Navigation Wiki - Metadata registry for project structure  
> **⚠️ CRITICAL:** Update this file with every structural change!  
> **📚 Strategy:** Metadata here → Details in `/docs/` → Code in `/setup-template/`

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
**Type:** Kubernetes Local Development Template  
**Current Status:** 🏗️ **IN DEVELOPMENT**  
**Architecture:** 2-Phase (Local → Cloud)

**Goal:**
Fast, automated Kubernetes setup for development with optional production deployment.

**Phases:**
1. **Local Dev** - kind cluster + demo app (~1 min setup)
2. **Cloud Deploy** - Argo CD GitOps + Azure AKS (planned)

**Target Users:**
- Developers needing quick local K8s
- Teams seeking production-ready templates
- K8s + GitOps learners

---

## 🗂️ File Registry (AI Navigation)

### **Core Documentation**

| File | Location | Content | When to Read |
|------|----------|---------|--------------|
| **README** | `/README.md` | Project overview, features, quick start | First time, project introduction |
| **Roadmap** | `/ROADMAP.md` | Phase 1+2 checklists, implementation status | Planning, progress tracking |
| **Quickstart** | `/docs/quickstart/Quickstart.md` | Setup guide, troubleshooting | Installation, first setup |
| **System Overview** | `/docs/SYSTEM_OVERVIEW.md` | Architecture diagrams, components | Understanding system design |
| **This File** | `/.github/copilot-instructions.md` | Metadata registry, navigation | AI orientation, finding files |

### **Code Structure**

| Path | Purpose | Contains |
|------|---------|----------|
| `/setup-template/` | Setup scripts | Phase 1+2 automation |
| `/setup-template/setup-phase1.sh` | Master script | Complete Phase 1 automation |
| `/setup-template/phase1/` | Phase 1 blocks | 6 setup blocks (tools, cluster, ingress, demo) |
| `/setup-template/phase1/*/test.sh` | Block tests | Validation scripts per block |
| `/docs/` | Documentation | Guides, architecture, troubleshooting |

### **Generated During Setup**

| Path | Created By | Purpose |
|------|-----------|---------|
| `apps/` | setup scripts | Application manifests |
| `clusters/` | setup scripts | Cluster configurations |
| `infrastructure/` | setup scripts | Shared infrastructure (ingress, etc.) |
| `policies/` | setup scripts | OPA/Gatekeeper policies |
| `kind-config.yaml` | setup scripts | kind cluster configuration |

---

## 🛠️ Tech Stack (Current)

### **Phase 1 - Local Development**
| Component | Version | Purpose |
|-----------|---------|---------|
| **Docker** | 28.5.0+ | Container runtime |
| **kind** | 0.20.0+ | Local Kubernetes clusters |
| **kubectl** | 1.28+ | Kubernetes CLI |
| **Helm** | 3.19.0+ | Package manager |
| **Argo CD CLI** | 2.13+ | GitOps tool (planned) |
| **Task** | 3.45.4+ | Task runner |
| **ingress-nginx** | latest | Ingress controller |
| **podinfo** | latest | Demo application |

### **Phase 2 - Cloud (Planned)**
| Component | Purpose | Status |
|-----------|---------|--------|
| **Argo CD** | GitOps automation | 📋 Planned |
| **Azure AKS** | Managed Kubernetes | 📋 Planned |
| **cert-manager** | TLS certificates | 📋 Planned |
| **Sealed Secrets** | Encrypted secrets | 📋 Planned |

---

## 🚀 Command Reference

### **Setup**
```bash
# Complete automated setup
./setup-template/setup-phase1.sh

# Test individual blocks
./setup-template/phase1/01-install-tools/test.sh
```

### **Cluster Management**
```bash
# Check cluster status
kubectl get pods -A

# Delete cluster
kind delete cluster --name agent-k8s-local
```

### **Cleanup**
```bash
# Remove all generated files
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

---

## 📊 Project Status

**Phase 1:** 🏗️ In Development  
**Phase 2:** 📋 Planned  
**Last Updated:** 06.01.2025

---

## 🎯 AI Quick Reference

**For setup questions:** → Read `/docs/quickstart/Quickstart.md`  
**For project overview:** → Read `/README.md`  
**For implementation details:** → Read `/ROADMAP.md`  
**For code execution:** → Run scripts in `/setup-template/`  
**For structure changes:** → **Update this file first!**

---