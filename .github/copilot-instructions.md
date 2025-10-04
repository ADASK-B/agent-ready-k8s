# GitHub Copilot Instructions - agent-ready-k8s

> **🎯 Purpose:** This file serves as a **table of contents/Wikipedia** for the project.  
> **⚠️ CRITICAL:** This file must be **kept up-to-date** with every change!  
> **📚 Strategy:** Only metadata here → Details in `/docs/` (token optimization)

---

## 🌍 PRIO 0: LANGUAGE RULE

**🚨 ALL CODE, DOCS, AND COMMITS MUST BE IN ENGLISH! 🚨**

**Rule:**
- ✅ Input language: Any (German, English, etc.)
- ✅ Output language: **ALWAYS ENGLISH**
- ✅ All files in repo: **ENGLISH ONLY**
- ✅ Commit messages: **ENGLISH ONLY**
- ✅ Comments in code: **ENGLISH ONLY**

**Example:**
```
User: "Füge eine neue Funktion hinzu"
Agent: *Writes code in English*
Agent: *Writes commit message in English*
```

---

## ⚠️ PRIO 1: MAINTENANCE DUTY

## ⚠️ PRIO 1: MAINTENANCE DUTY

**🚨 UPDATE THIS FILE WITH EVERY STRUCTURAL CHANGE! 🚨**

**When to update:**
- ✅ New scripts/blocks added → Update Commands section
- ✅ New docs files created → Expand Documentation Structure
- ✅ Folders renamed/moved → Update Project Structure
- ✅ New known issues → Add to "Known Issues"
- ✅ Tools/versions changed → Update Stack section
- ✅ Phase status changed → Update Status Banner

**Why critical:**
- Agents (like me) read this file first
- Outdated info → wrong decisions
- New contributors rely on it
- This file = Single Source of Truth for navigation

---

## 📖 Project Overview

**Name:** agent-ready-k8s  
**Type:** Kubernetes Template Stack (local + cloud)  
**Phase 1 Status:** ✅ COMPLETED (1m 10s runtime, 46/46 tests)  
**Phase 2 Status:** ⏸️ PLANNED (GitOps + AKS)

**What is this?**
A fully automated Kubernetes setup for local development (Phase 1) with optional cloud deployment (Phase 2).
- **Phase 1:** Local kind cluster + podinfo demo in ~1 minute
- **Phase 2:** GitOps with Flux + Azure AKS deployment

**For whom?**
- Developers who need a fast local K8s environment
- Teams looking for a production-ready template
- Learners for Kubernetes + GitOps best practices

**Quick Start (1 command):**
```bash
./setup-template/setup-phase1.sh
```
→ After 1m 10s: http://demo.localhost runs podinfo v6.9.2

---

## 🗂️ Documentation Structure

### **1. Quick Start** → `/docs/quickstart/`
**When to use:** First steps, complete setup from scratch, OR after reboot
- `Quickstart.md` - Complete guide for Phase 1 setup
- **Content:** 
  - Tool installation, cluster setup, demo deployment
  - ⭐ **After Reboot:** Restart cluster (3 commands, ~1 min)
  - Fast Track (fully automated, 1 command)
  - Manual steps (step-by-step)
  - Troubleshooting (7 common problems)
- **Runtime:** 
  - First setup: ~4-5 min (with Docker install + reboot)
  - After reboot: ~1 min (images cached!)
  - Fast Track: ~1m 10s (tools present)
- **Result:** http://demo.localhost running

### **2. Roadmap** → `ROADMAP.md` (Root)
**When to use:** Overview of Phase 1 + Phase 2, track progress
- **Content:** Detailed checklists, performance reports, costs
- **Status:** Current (Phase 1 fully marked complete)

### **3. README** → `README.md` (Root)
**When to use:** Project overview, features, credits
- **Content:** What is the project, why does it exist, who uses it
- **Status:** 🚧 Needs update (new script path)

---

## 🛠️ Tech Stack

### **Phase 1 - Local (✅ COMPLETED)**
- **Container:** Docker 28.5.0
- **K8s:** kind v0.20.0 (Cluster: agent-k8s-local, K8s v1.27.3)
- **Tools:** kubectl v1.34.1, Helm v3.19.0, Flux CLI v2.7.0, Task 3.45.4
- **Ingress:** ingress-nginx (hostPort mode for kind)
- **Demo App:** podinfo v6.9.2 (2 replicas)
- **URL:** http://demo.localhost

### **Phase 2 - Cloud (⏸️ PLANNED)**
- **GitOps:** Flux v2.7.0 (auto-deploy on git push)
- **Cloud:** Azure AKS (Free Tier control plane, 3 nodes)
- **CI/CD:** GitHub Actions (Trivy, Gitleaks, kubeconform)
- **Secrets:** Sealed Secrets (encrypted in Git)
- **TLS:** cert-manager + Let's Encrypt
- **Cost:** ~88€/month (estimated)

---

## 📁 Project Structure

```
agent-ready-k8s/
├── .github/
│   └── copilot-instructions.md    ← This file (table of contents)
├── docs/
│   └── quickstart/
│       └── Quickstart.md          ← Complete setup guide
├── setup-template/
│   ├── setup-phase1.sh            ← Master script (1 command)
│   └── phase1/                    ← 6 blocks (action + test)
│       ├── 01-install-tools/
│       ├── 02-create-structure/
│       ├── 03-clone-templates/
│       ├── 04-create-cluster/
│       ├── 05-deploy-ingress/
│       └── 06-deploy-podinfo/
├── apps/podinfo/                  ← FluxCD GitOps manifests
│   ├── base/
│   └── tenants/demo/
├── clusters/                      ← Cluster configurations
│   ├── local/                     (Phase 1)
│   └── production/                (Phase 2)
├── infrastructure/                ← Shared infra (Ingress, Sealed Secrets)
├── policies/                      ← OPA/Gatekeeper policies
├── kind-config.yaml               ← kind cluster config (ports 80/443)
├── ROADMAP.md                     ← Detailed Phase 1+2 checklists
└── README.md                      ← Project overview
```

---

## 🚀 Most Important Commands

### **Phase 1 - Complete Setup**
```bash
# Fully automated setup (1m 10s)
./setup-template/setup-phase1.sh

# Check cluster status
kubectl get pods -A
curl http://demo.localhost

# Delete cluster (restart)
kind delete cluster --name agent-k8s-local
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

### **After Reboot - Restart Cluster** ⭐
```bash
cd ~/agent-ready-k8s

# Option 1: Cluster only (Git manifests unchanged, ~1 min)
./setup-template/phase1/04-create-cluster/create.sh  # ~10s (images cached!)
./setup-template/phase1/05-deploy-ingress/deploy.sh  # ~25s
./setup-template/phase1/06-deploy-podinfo/deploy.sh  # ~8s

# Option 2: Fully automated (~1m 10s, overwrites apps/)
./setup-template/setup-phase1.sh

# Test
curl http://demo.localhost
```

**Why so fast after reboot?** Docker images are cached (kindest/node, ingress-nginx, podinfo)!

### **Phase 1 - Test Individual Blocks**
```bash
# Blocks 1-2: Tools
./setup-template/phase1/01-install-tools/test.sh

# Block 5: Cluster
./setup-template/phase1/04-create-cluster/test.sh

# Block 7: podinfo
./setup-template/phase1/06-deploy-podinfo/test.sh
```

### **Phase 2 - GitOps (Planned)**
```bash
# Flux Bootstrap
flux bootstrap github --owner=ADASK-B --repository=agent-ready-k8s --branch=main --path=clusters/local

# Deploy changes
git add apps/podinfo/tenants/demo/patch.yaml
git commit -m "feat: scale to 3 replicas"
git push  # → Flux deploys automatically
```

---

## 🔧 Known Issues & Fixes

### **Issue: System pods not immediately ready**
- **Symptom:** Test fails directly after cluster creation
- **Fix:** Retry logic (3×2s) in `04-create-cluster/test.sh`
- **Solution:** ✅ Implemented

### **Issue: HTTP 503 after podinfo deploy**
- **Symptom:** curl http://demo.localhost returns 503
- **Fix:** Retry logic (5×3s) for ingress propagation
- **Solution:** ✅ Implemented in `06-deploy-podinfo/test.sh`

### **Issue: kind port mapping 80/443 not possible**
- **Symptom:** NodePort can't bind to 80/443
- **Fix:** `hostPort.enabled=true` instead of `nodePorts.http=80`
- **Solution:** ✅ Implemented in `05-deploy-ingress/deploy.sh`

### **Issue: FluxCD repo has no staging manifests**
- **Symptom:** Clone script doesn't find tenant overlays
- **Fix:** Fallback creation in `03-clone-templates/clone.sh`
- **Solution:** ✅ Implemented

---

## 📊 Performance Metrics (Phase 1)

```
Runtime:        1m 9.6s (instead of estimated 20-30 min)
Tests:          46/46 passed (100%)
Setup Method:   Fully automated (1 command)
Retry Fixes:    2 (System Pods, HTTP Endpoint)
```

**Block Breakdown (First Setup):**
- Tools:      7/7 Tests ✅  ~5s
- Structure: 10/10 Tests ✅  ~2s
- Manifests:  5/5 Tests ✅  ~5s
- Cluster:    5/5 Tests ✅ ~17s
- Ingress:    7/7 Tests ✅ ~20s
- podinfo:   12/12 Tests ✅  ~8s

**After Reboot (Images Cached):** ⭐
- Cluster:    5/5 Tests ✅ ~10s (instead of 17s)
- Ingress:    7/7 Tests ✅ ~25s (instead of 45s)
- podinfo:   12/12 Tests ✅  ~8s (unchanged)
- **TOTAL:**              **~43s** 🚀 (instead of 1m 10s)

---

## 🎯 Next Steps for Agent

1. **For setup questions:** Read `/docs/quickstart/Quickstart.md`
2. **After reboot / "restart it":** See Quickstart.md → "After Reboot" section ⭐
3. **For Phase 1/2 details:** Read `ROADMAP.md`
4. **For test failures:** Check "Known Issues & Fixes" (above)
5. **For project context:** Read `README.md`

---

## ⚠️ Maintenance Rules

1. **Update this file** when:
   - New scripts/blocks added
   - New docs files created
   - Commands changed
   - New known issues found
   - Structure changes

2. **Update docs files** when:
   - Tool versions change
   - Runtime improvements made
   - New features/blocks added
   - Workflows changed

3. **Update ROADMAP.md** when:
   - Tasks completed
   - New Phase 2 plans
   - Performance changes

---

**Last Updated:** 04.10.2025  
**Version:** Phase 1 Complete (v1.0)
