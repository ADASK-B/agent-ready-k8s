# 🗺️ ROADMAP - agent-ready-k8s

> **Phase 1:** Local Kubernetes setup (~1-2 min)  
> **Phase 2:** GitOps + Azure AKS (planned)

---

## 🚀 Quick Start

```bash
./setup-template/setup-phase1.sh
```

---

## ✅ Phase 1 Checklist

### **Block 1: Tools Installation**
- [ ] Docker installed and running (`docker --version`)
- [ ] kind installed (`kind version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm installed (`helm version`)
- [ ] Argo CD CLI installed (`argocd version --client`)
- [ ] Task installed (`task --version`)

**Test:** `./setup-template/phase1/01-install-tools/test.sh`

---

### **Block 2: Project Structure**
- [ ] Folders created (`apps/`, `clusters/`, `infrastructure/`, `policies/`)
- [ ] `kind-config.yaml` exists in root
- [ ] `.gitignore` created

**Test:** `./setup-template/phase1/02-create-structure/test.sh`

---

### **Block 3: Templates**
- [ ] `apps/podinfo/base/` contains manifests
- [ ] `apps/podinfo/tenants/demo/` contains overlays

**Test:** `./setup-template/phase1/03-clone-templates/test.sh`

---

### **Block 4: Cluster**
- [ ] kind cluster created (`kind get clusters` → `agent-k8s-local`)
- [ ] kubectl context set (`kubectl config current-context` → `kind-agent-k8s-local`)
- [ ] Node ready (`kubectl get nodes` → `Ready`)

**Test:** `./setup-template/phase1/04-create-cluster/test.sh`

---

### **Block 5: Ingress**
- [ ] ingress-nginx namespace created
- [ ] Ingress controller pod running (`kubectl get pods -n ingress-nginx`)

**Test:** `./setup-template/phase1/05-deploy-ingress/test.sh`

---

### **Block 6: Demo App**
- [ ] `tenant-demo` namespace created
- [ ] podinfo pods running (`kubectl get pods -n tenant-demo` → `2/2 Running`)
- [ ] Ingress created (`kubectl get ingress -n tenant-demo`)
- [ ] HTTP endpoint works (`curl http://demo.localhost` → HTTP 200)
- [ ] Browser works (`http://demo.localhost` → podinfo UI)

**Test:** `./setup-template/phase1/06-deploy-podinfo/test.sh`

---

## 🎯 Phase 1 Complete When:

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| **Cluster** | `kind get clusters` | `agent-k8s-local` | ⬜ |
| **Nodes** | `kubectl get nodes` | 1 node Ready | ⬜ |
| **Ingress** | `kubectl get pods -n ingress-nginx` | 1/1 Running | ⬜ |
| **podinfo** | `kubectl get pods -n tenant-demo` | 2/2 Running | ⬜ |
| **HTTP** | `curl http://demo.localhost` | HTTP 200 | ⬜ |
| **Browser** | Open `http://demo.localhost` | podinfo UI | ⬜ |

---

## 📋 Phase 2 Checklist (Planned)

- [ ] GitHub Actions CI/CD configured
- [ ] Argo CD installed in cluster
- [ ] Argo CD applications created
- [ ] Azure AKS cluster created
- [ ] GitOps workflow: `git push` → auto-deploy
- [ ] TLS certificates (Let's Encrypt)
- [ ] Production monitoring

---

## 🧹 Cleanup

```bash
# Delete cluster
kind delete cluster --name agent-k8s-local

# Remove generated files
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml
```

---

**Last Updated:** 06.01.2025  
**Status:** Phase 1 ready to start 🚀
