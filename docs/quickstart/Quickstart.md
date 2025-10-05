# 🚀 Quick Start - agent-ready-k8s

> **Scenario:** Fresh Ubuntu machine + VSCode + Git Clone → Running Demo  
> **Goal:** http://demo.localhost shows podinfo v6.9.2 in ~2 minutes  
> **Status:** Phase 1 (Local with kind)

---

## ⚡ Fast Track - Fully Automated (1 Command)

**If you already have all tools installed:**

```bash
cd ~/agent-ready-k8s
./setup-template/setup-phase1.sh
```

**Runtime:** ~1 minute 10 seconds

**What the script does:**
1. ✅ Checks tools (Docker, kind, kubectl, helm, flux)
2. ✅ Creates folder structure (if not exists)
3. ⚠️  Clones FluxCD templates (**overwrites apps/podinfo/**)
4. ✅ Creates kind cluster (agent-k8s-local)
5. ✅ Deploys ingress-nginx
6. ✅ Deploys podinfo
7. ✅ Runs 46 tests

**⚠️ WARNING:** Block 3 overwrites `apps/podinfo/` with FluxCD templates!  
→ Only use if you want to reset manifests.

**Better for production:**  
→ Follow the manual guide below (skips Block 2+3, uses Git manifests)

---

## 🔄 After Reboot - Restart Cluster

**Situation:** You restarted your machine, cluster might be stopped.

---

### **🤖 For AI Agents: Smart Restart Decision Tree**

**Step 1: Check what exists**
```bash
# Does cluster exist?
kind get clusters 2>/dev/null | grep -q "agent-k8s-local"
# Exit code 0 = exists, 1 = doesn't exist

# Is cluster responding?
kubectl cluster-info --context kind-agent-k8s-local 2>&1 | grep -q "is running"
# Exit code 0 = works, 1 = stopped/broken
```

**Step 2: Decide action based on checks**

| Check Result | Action | Reason |
|-------------|--------|---------|
| Cluster doesn't exist | Run: `04-create-cluster/create.sh` | Need fresh cluster |
| Cluster exists but stopped | Delete first, then recreate | Container stopped, can't restart kind containers |
| Cluster works | Skip cluster creation! | Already running, save time |
| Cluster works but 503 error | Only redeploy Ingress + podinfo | Cluster OK, apps need restart |

**Step 3: Execute minimal actions**

```bash
# Scenario A: No cluster exists
if ! kind get clusters 2>/dev/null | grep -q "agent-k8s-local"; then
  echo "📦 No cluster, creating..."
  ./setup-template/phase1/04-create-cluster/create.sh
  ./setup-template/phase1/05-deploy-ingress/deploy.sh
  ./setup-template/phase1/06-deploy-podinfo/deploy.sh
  
# Scenario B: Cluster exists but stopped
elif ! kubectl cluster-info --context kind-agent-k8s-local 2>&1 | grep -q "is running"; then
  echo "❌ Cluster stopped, recreating..."
  kind delete cluster --name agent-k8s-local
  ./setup-template/phase1/04-create-cluster/create.sh
  ./setup-template/phase1/05-deploy-ingress/deploy.sh
  ./setup-template/phase1/06-deploy-podinfo/deploy.sh
  
# Scenario C: Cluster works
else
  echo "✅ Cluster running! Testing endpoint..."
  if curl -f http://demo.localhost >/dev/null 2>&1; then
    echo "🎉 Everything works! Nothing to do."
  else
    echo "⚠️  Cluster OK but endpoint fails, redeploying apps..."
    ./setup-template/phase1/05-deploy-ingress/deploy.sh
    ./setup-template/phase1/06-deploy-podinfo/deploy.sh
  fi
fi
```

**Why this is smart:**
- ✅ Checks **before** deleting
- ✅ Minimal actions (don't recreate if not needed)
- ✅ Detects: no cluster, stopped cluster, working cluster
- ✅ Saves time when cluster still works

---

### **👤 For Humans: Quick Commands**

**First: Check status** (always do this!)
```bash
# Does cluster exist?
kind get clusters
# Output: "agent-k8s-local" = exists, empty = doesn't exist

# Is it working?
kubectl cluster-info --context kind-agent-k8s-local
# "is running" = works ✅
# "Unable to connect" = stopped ❌
```

---

#### **Option 1: Smart restart (checks first)**

**Copy-paste this** (works for all scenarios):
```bash
cd ~/agent-ready-k8s

# Check and decide
if ! kind get clusters 2>/dev/null | grep -q "agent-k8s-local"; then
  echo "📦 Creating new cluster..."
  ./setup-template/phase1/04-create-cluster/create.sh
elif ! kubectl cluster-info --context kind-agent-k8s-local 2>&1 | grep -q "is running"; then
  echo "❌ Cluster stopped, deleting and recreating..."
  kind delete cluster --name agent-k8s-local
  ./setup-template/phase1/04-create-cluster/create.sh
else
  echo "✅ Cluster already running, skipping creation!"
fi

# Always redeploy apps (fast, idempotent)
./setup-template/phase1/05-deploy-ingress/deploy.sh
./setup-template/phase1/06-deploy-podinfo/deploy.sh

# Test
curl http://demo.localhost
```

**Runtime:** 
- Cluster exists + works: ~1 min (only redeploy apps)
- Cluster stopped: ~2 min (delete + recreate + apps)

---

#### **Option 2: Force fresh start (always delete)**

**Use when:** You want guaranteed clean state
```bash
cd ~/agent-ready-k8s

# Delete if exists
kind delete cluster --name agent-k8s-local 2>/dev/null || true

# Recreate everything
./setup-template/phase1/04-create-cluster/create.sh  # ~17s
./setup-template/phase1/05-deploy-ingress/deploy.sh  # ~45s
./setup-template/phase1/06-deploy-podinfo/deploy.sh  # ~12s

# Test
curl http://demo.localhost
```
# Test
curl http://demo.localhost
```

**Runtime:** ~2 min (always recreates cluster)

---

#### **Option 3: Full automation (overwrites Git manifests!)**

**⚠️ WARNING:** Uses setup-phase1.sh which asks about deleting cluster!
```bash
cd ~/agent-ready-k8s
./setup-template/setup-phase1.sh
```

**Overwrites:** `apps/podinfo/` from Git templates  
**Use when:** You want to reset manifests to defaults

---

### **What persists after reboot?**
- ✅ Docker (auto-starts on boot)
- ✅ Tools (kind, kubectl, helm, flux)
- ✅ Git repo (apps/, clusters/, manifests)
- ✅ Docker images (cached! ~770MB)

### **What's lost after reboot?**
- ❌ kind cluster (Docker container stops)
- ❌ All pods (namespaces gone)
- ❌ Ingress controller (needs redeploy)

### **Why so fast after reboot?**
Docker has cached images:
```bash
docker images
# kindest/node:v1.27.3       (500MB) ✅ cached
# ingress-nginx/controller   (200MB) ✅ cached
# podinfo:6.9.2              (20MB)  ✅ cached
```

**No re-download needed!** 🚀

---

### **Troubleshooting after reboot:**

#### **Docker not running?**
```bash
sudo systemctl status docker
# If inactive:
sudo systemctl start docker
```

#### **Tools not found?**
```bash
kind version || echo "PATH Problem!"
# Fix:
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

#### **Port 80/443 occupied?**
```bash
sudo lsof -i :80
sudo lsof -i :443
# Stop Apache:
sudo systemctl stop apache2
sudo systemctl disable apache2
```

---

**Details:** See [Step 3-6](#️-step-3-create-kind-cluster-30-seconds) for manual steps

---

## 📗🗂️ Table of Contents

1. [After Reboot - Restart Cluster](#-after-reboot---restart-cluster) ⭐ **New!**
2. [What's already here after git clone?](#-whats-already-here-after-git-clone)
3. [System Requirements](#-system-requirements)
4. [Setup Workflow](#-setup-workflow-from-zero-to-running)
5. [Step 1: System Check](#-step-1-system-check)
6. [Step 2: Install Tools](#️-step-2-install-tools)
7. [Step 3: Create Cluster](#️-step-3-create-kind-cluster-30-seconds)
8. [Step 4: Deploy Ingress](#-step-4-deploy-ingress-controller-45-seconds)
9. [Step 5: Deploy podinfo](#-step-5-deploy-podinfo-20-seconds)
10. [Step 6: Success Validation](#-step-6-success-validation-30-seconds)
11. [Troubleshooting](#-troubleshooting---common-issues)
12. [Cleanup & Reset](#-cleanup--reset)
13. [Performance Metrics](#-performance-metrics-reference)
14. [Next Steps](#-next-steps---whats-now)

---

## 📦 What's already here after `git clone`?
```
agent-ready-k8s/
├── apps/podinfo/base/           ← Kubernetes Manifeste (Deployment, Service, HPA)
├── apps/podinfo/tenants/demo/   ← Kustomize Overlays (2 Replicas, Ingress)
├── clusters/local/              ← Cluster-Configs (leer, für Phase 2 Flux)
├── infrastructure/              ← Shared Infra (leer, für Phase 2)
├── policies/                    ← OPA Policies (leer, für Phase 2)
├── setup-template/              ← Alle Scripts (install, deploy, test)
└── docs/                        ← Diese Anleitung
```

**🎯 Das bedeutet:**
- podinfo Manifeste **existieren bereits** (aus Phase 1 Development)
- Du musst sie **NICHT neu generieren**
- Scripts deployen diese Manifeste in deinen Cluster

### **❌ Was fehlt noch?**
```
1. Tools (Docker, kind, kubectl, helm, flux)
2. kind-Cluster (agent-k8s-local)
3. Ingress-Controller (ingress-nginx)
4. Running Pods (in Namespace tenant-demo)
```

**Das bauen wir jetzt auf! ⬇️**

---

## 📋 System-Anforderungen

### **Hardware**
- **CPU:** 2+ Cores (empfohlen 4)
- **RAM:** 8GB (empfohlen 16GB)
- **Disk:** 20GB freier Speicher
- **Internet:** Für Image-Downloads (docker.io, ghcr.io)

### **Software (Vorinstalliert)**
- ✅ Ubuntu 20.04+ (oder Debian-basiert)
- ✅ VSCode (bereits installiert)
- ✅ Git (für `git clone`)

### **Berechtigungen**
- ✅ `sudo` Zugriff erforderlich (für Tool-Installation)
- ⚠️ User muss in `docker` Gruppe (wird automatisch hinzugefügt, **Reboot nötig!**)

---

## 🚀 Setup-Workflow (Von Null zu Running)

### **Overview:**
```
1. System Check          → Check Ubuntu/Git/curl           (~10s)
2. Tools Install         → Docker + K8s Tools              (~3min)
   └─ 2.1 Docker         → Install + add user to group     (~90s + reboot)
   └─ 2.2 K8s Tools      → kind, kubectl, helm, flux       (~60s)
3. Cluster Create        → kind cluster with config        (~30s)
4. Ingress Deploy        → ingress-nginx (LoadBalancer)    (~45s)
5. podinfo Deploy        → Demo app with Ingress           (~20s)
6. Success Check         → Pods + HTTP Endpoint            (~30s)
```

**Total runtime:** ~4-5 minutes (incl. Docker reboot)

**After reboot:** Only 3-6 (~2 minutes, images cached!)

---

## 🔍 Step 1: System Check

### **What are we checking?**
```
1. System Check          (~1 min)   ← Prüfen was fehlt
2. Tools installieren    (~2 min)   ← Docker, kind, kubectl, helm, flux
   └─ REBOOT ERFORDERLICH nach Docker!
3. Cluster erstellen     (~30 sec)  ← kind create cluster
4. Ingress deployen      (~45 sec)  ← nginx-ingress (Helm)
5. podinfo deployen      (~20 sec)  ← kubectl apply -k (aus Git!)
6. Erfolgskontrolle      (~10 sec)  ← curl + kubectl tests
──────────────────────────────────
TOTAL:                   ~5-6 min (inkl. Downloads)
```

**⚡ Schneller Weg:**
```bash
./setup-template/setup-phase1.sh  # Alles automatisch (~1m 10s)
```

---

## 🔍 Schritt 1: System Check

### **Was prüfen wir?**
```bash
# In agent-ready-k8s/ Verzeichnis
cd ~/agent-ready-k8s  # oder dein clone path

# 1. Ist Docker installiert?
docker --version 2>/dev/null || echo "❌ Docker fehlt"

# 2. Sind andere Tools da?
kind version 2>/dev/null || echo "❌ kind fehlt"
kubectl version --client 2>/dev/null || echo "❌ kubectl fehlt"
helm version 2>/dev/null || echo "❌ helm fehlt"
flux version 2>/dev/null || echo "❌ flux fehlt"

# 3. Ist Port 80/443 frei?
sudo lsof -i :80 || echo "✅ Port 80 frei"
sudo lsof -i :443 || echo "✅ Port 443 frei"
```

**Erwartung:**
- **Erste Installation:** Alle Tools fehlen → Weiter zu Schritt 2
- **Nach Reboot:** Nur Cluster fehlt → Springe zu Schritt 3

---

## 🛠️ Schritt 2: Tools installieren

### **2.1 Docker installieren** (~90 Sekunden)

```bash
# Docker Repository hinzufügen
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# User zu docker Gruppe hinzufügen
sudo usermod -aG docker $USER

# ⚠️ WICHTIG: Reboot erforderlich!
echo "⚠️  Docker installiert - REBOOT ERFORDERLICH!"
echo "Nach Reboot: Weiter bei Schritt 2.2"
```

**Test (nach Reboot):**
```bash
docker run hello-world
# Expected: "Hello from Docker!" Nachricht
```

---

### **2.2 Install Kubernetes Tools** (~60 seconds)

```bash
# kind (Kubernetes in Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl (Kubernetes CLI)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Helm (Package Manager)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Flux CLI (GitOps)
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installations
kind version
kubectl version --client
helm version
flux version
```

**All tools installed!** ✅

---

## ☸️ Step 3: Create kind Cluster (~30 seconds)

### **What happens here?**

**Troubleshooting:**
- **Fehler: "permission denied"** → Docker-Gruppe fehlt
  ```bash
  sudo usermod -aG docker $USER
  sudo reboot
  ```

- **Fehler: "command not found"** → PATH fehlt
  ```bash
  echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
  source ~/.bashrc
  ```

---

## ☸️ Schritt 3: kind-Cluster erstellen (~30 Sekunden)

### **Was passiert hier?**
- Erstellt Docker-Container als "Kubernetes Node"
- Nutzt `kind-config.yaml` (bereits in Git)
- Mappt Ports 80/443 für Ingress

```bash
cd ~/agent-ready-k8s

# Cluster erstellen
./setup-template/phase1/04-create-cluster/create.sh
```

**Das Script macht:**
1. Prüft ob `kind-config.yaml` existiert (✅ in Git vorhanden)
2. Falls fehlend: Erstellt Config mit Port-Mappings
3. Erstellt Cluster: `kind create cluster --config kind-config.yaml`
4. Wartet bis System-Pods ready sind

**Test:**
```bash
# Cluster erreichbar?
kubectl cluster-info
# Expected: Kubernetes control plane is running at https://127.0.0.1:xxxxx

# Nodes ready?
kubectl get nodes
# Expected:
# NAME                           STATUS   ROLES           AGE   VERSION
# agent-k8s-local-control-plane  Ready    control-plane   30s   v1.27.3

# System Pods laufen?
kubectl get pods -n kube-system
# Expected: coredns, etcd, kube-apiserver, kube-controller-manager, kube-proxy → ALL Running
```

**Troubleshooting:**
- **Fehler: "cluster already exists"**
  ```bash
  kind delete cluster --name agent-k8s-local
  ./setup-template/phase1/04-create-cluster/create.sh
  ```

- **Fehler: "failed to create cluster"** → Port 80/443 belegt
  ```bash
  sudo lsof -i :80
  sudo lsof -i :443
  # Stoppe blockierenden Prozess (z.B. Apache)
  sudo systemctl stop apache2
  ```

---

## 🌐 Schritt 4: Ingress-Controller deployen (~45 Sekunden)

### **Was ist Ingress-Controller?**
- Ermöglicht HTTP-Zugriff von außen (http://demo.localhost)
- Wir nutzen `ingress-nginx` (offizieller NGINX Controller)
- Deployed via **Helm Chart** (daher brauchen wir Helm!)

```bash
cd ~/agent-ready-k8s

# Ingress deployen
./setup-template/phase1/05-deploy-ingress/deploy.sh
```

**Das Script macht:**
1. Fügt Helm Repo hinzu: `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
2. Installiert Chart mit hostPort-Mode (kind-kompatibel):
   ```bash
   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx --create-namespace \
     --set controller.hostPort.enabled=true \
     --set controller.service.type=NodePort
   ```
3. Wartet bis Controller-Pod ready ist

**Test:**
```bash
# Namespace existiert?
kubectl get namespace ingress-nginx
# Expected: ingress-nginx   Active   30s

# Controller läuft?
kubectl get pods -n ingress-nginx
# Expected:
# NAME                                        READY   STATUS    AGE
# ingress-nginx-controller-xxxxx              1/1     Running   30s

# Service ready?
kubectl get svc -n ingress-nginx
# Expected: ingress-nginx-controller   NodePort   10.96.x.x   80:xxxxx/TCP,443:xxxxx/TCP

# Admission Webhook erreichbar?
kubectl get validatingwebhookconfigurations
# Expected: ingress-nginx-admission
```

**Troubleshooting:**
- **Pod bleibt in ContainerCreating** → Warten (Image-Download)
  ```bash
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=ingress-nginx \
    -n ingress-nginx --timeout=120s
  ```

- **Error: "admission webhook denied"** → Webhook nicht ready, warten 10s

---

## 🚀 Schritt 5: podinfo deployen (~20 Sekunden)

### **Was ist podinfo?**
- Demo-App von Stefan Prodan (FluxCD Maintainer)
- Zeigt Kubernetes Best Practices
- Wir deployen **aus Git-Manifesten** (apps/podinfo/)

### **Warum nicht neu generieren?**
- Manifeste existieren bereits in Git (Phase 1 Development)
- Git = Single Source of Truth (wichtig für Phase 2 GitOps!)
- Du könntest sie auch manuell editieren

```bash
cd ~/agent-ready-k8s

# podinfo deployen
./setup-template/phase1/06-deploy-podinfo/deploy.sh
```

**Das Script macht:**
1. Erstellt Namespace: `kubectl create namespace tenant-demo`
2. Deployed mit Kustomize: `kubectl apply -k apps/podinfo/tenants/demo/`
3. Wartet bis Pods ready sind (2 Replicas)

**Was wird deployed?**
```
apps/podinfo/base/
├── deployment.yaml       ← 2 Replicas, Resource Limits
├── hpa.yaml              ← Horizontal Pod Autoscaler (später)
├── kustomization.yaml    ← Kustomize Base
└── service.yaml          ← ClusterIP Service (Port 9898)

apps/podinfo/tenants/demo/
├── kustomization.yaml    ← Referenziert ../base
├── patch.yaml            ← Überschreibt Replicas, fügt Ingress hinzu
└── (Ingress wird inline in patch.yaml definiert)
```

**Test:**
```bash
# Namespace existiert?
kubectl get namespace tenant-demo
# Expected: tenant-demo   Active   10s

# Pods laufen?
kubectl get pods -n tenant-demo
# Expected:
# NAME                       READY   STATUS    AGE
# podinfo-7d8b5c5f9d-xxxxx   1/1     Running   10s
# podinfo-7d8b5c5f9d-yyyyy   1/1     Running   10s

# Service existiert?
kubectl get svc -n tenant-demo
# Expected: podinfo   ClusterIP   10.96.x.x   9898/TCP

# Ingress existiert?
kubectl get ingress -n tenant-demo
# Expected:
# NAME      CLASS   HOSTS             ADDRESS     PORTS   AGE
# podinfo   nginx   demo.localhost    localhost   80      10s
```

**Troubleshooting:**
- **Pods in ImagePullBackOff** → Docker Hub Rate Limit
  ```bash
  kubectl describe pod -n tenant-demo podinfo-xxxxx
  # Warten 5 Minuten, dann retry
  kubectl rollout restart deployment podinfo -n tenant-demo
  ```

- **Ingress hat kein ADDRESS** → Warten 10s, dann retry
  ```bash
  kubectl get ingress -n tenant-demo -w
  ```

---

## ✅ Step 6: Success Validation (~30 seconds)

### **6.1 All pods running?**
```bash
kubectl get pods -A
```

**Expected:**
```
NAMESPACE        NAME                                        READY   STATUS    AGE
ingress-nginx    ingress-nginx-controller-xxxxxxxxx-xxxxx    1/1     Running   1m
kube-system      coredns-5d78c9869d-xxxxx                    1/1     Running   2m
kube-system      coredns-5d78c9869d-yyyyy                    1/1     Running   2m
kube-system      etcd-agent-k8s-local-control-plane          1/1     Running   2m
kube-system      kube-apiserver-agent-k8s-local-control...   1/1     Running   2m
kube-system      kube-controller-manager-agent-k8s-loca...   1/1     Running   2m
kube-system      kube-proxy-xxxxx                            1/1     Running   2m
kube-system      kube-scheduler-agent-k8s-local-control...   1/1     Running   2m
tenant-demo      podinfo-7d8b5c5f9d-xxxxx                    1/1     Running   30s
tenant-demo      podinfo-7d8b5c5f9d-yyyyy                    1/1     Running   30s
```

**All must be `Running` + `1/1 Ready`!**

---

### **6.2 HTTP endpoint responding?**

#### **Option A: curl (Terminal)**
```bash
curl http://demo.localhost
```

**Expected:**
```json
{
  "hostname": "podinfo-7d8b5c5f9d-xxxxx",
  "version": "6.9.2",
  "revision": "...",
  "color": "#34577c",
  "message": "greetings from podinfo v6.9.2"
}
```

#### **Option B: Browser**
Open: **http://demo.localhost**

**Expected:**
- Blue UI with podinfo logo
- Version: 6.9.2
- Hostname shows pod name
- Tabs: Home, Status, Metrics, Swagger

#### **Option C: Health Check**
```bash
curl http://demo.localhost/healthz
```

**Expected:**
```json
{"status":"ok"}
```

---

### **6.3 Run tests automatically**
```bash
cd ~/agent-ready-k8s

# Test: Cluster
./setup-template/phase1/04-create-cluster/test.sh
# Expected: 5/5 Tests ✅

# Test: Ingress
./setup-template/phase1/05-deploy-ingress/test.sh
# Expected: 7/7 Tests ✅

# Test: podinfo
./setup-template/phase1/06-deploy-podinfo/test.sh
# Expected: 12/12 Tests ✅
```

**Total: 24/24 tests should pass!**

---

### **6.4 What if HTTP 503?**

**Problem:**
```bash
curl http://demo.localhost
# <html>
# <head><title>503 Service Temporarily Unavailable</title></head>
```

**Cause:** Ingress controller still propagating (10-15s after pod ready)

**Solution: Retry with backoff**
```bash
for i in {1..5}; do
  echo "Attempt $i/5..."
  curl -I http://demo.localhost && break || sleep 3
done
```

**If still 503:**
```bash
# Check Ingress status
kubectl describe ingress podinfo -n tenant-demo

# Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Check /etc/hosts
grep demo.localhost /etc/hosts || echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts
```

---

## 🔍 Troubleshooting - Common Issues

### **Problem 1: Docker Permission Denied**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Cause:** User not in `docker` group

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker  # Temporary, or:
sudo reboot    # Persistent
```

**Test:**
```bash
docker ps  # Should NO longer show permission error
```

---

### **Problem 2: Port 80 already in use**
```
Error: failed to create cluster: ... address already in use
```

**Cause:** Another process is using port 80/443 (e.g. Apache, nginx)

**Solution:**
```bash
# Find process
sudo lsof -i :80
sudo lsof -i :443

# Example: Stop Apache
sudo systemctl stop apache2
sudo systemctl disable apache2  # Disable autostart

# Recreate cluster
kind delete cluster --name agent-k8s-local
./setup-template/phase1/04-create-cluster/create.sh
```

---

### **Problem 3: Pods stuck in Pending/ContainerCreating**
```bash
kubectl get pods -A
# STATUS: Pending or ContainerCreating (>1 minute)
```

**Cause:** Image download still running (Docker Hub rate limit or slow connection)

**Solution:**
```bash
# Wait until pods ready (max 2 minutes)
kubectl wait --for=condition=ready pod --all -n ingress-nginx --timeout=120s
kubectl wait --for=condition=ready pod --all -n tenant-demo --timeout=120s

# Check events
kubectl get events -n tenant-demo --sort-by='.lastTimestamp'

# Check pod details
kubectl describe pod -n tenant-demo podinfo-xxxxx
```

**If Docker Hub rate limit:**
```
Warning  Failed     ... Error: ImagePullBackOff ... toomanyrequests
```
→ Wait 5-10 minutes, then:
```bash
kubectl rollout restart deployment podinfo -n tenant-demo
```

---

### **Problem 4: demo.localhost not reachable**
```bash
curl http://demo.localhost
# curl: (6) Could not resolve host: demo.localhost
```

**Cause:** `/etc/hosts` missing entry

**Solution:**
```bash
# Add entry
echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts

# Verify
cat /etc/hosts | grep demo.localhost
# Expected: 127.0.0.1 demo.localhost

# Retry
curl http://demo.localhost
```

---

### **Problem 5: HTTP 503 Service Unavailable**
```bash
curl http://demo.localhost
# <html><head><title>503 Service Temporarily Unavailable</title></head>
```

**Cause:** Ingress controller still propagating (~10-15s after pod ready)

**Solution:**
```bash
# Retry with backoff
for i in {1..5}; do
  echo "Attempt $i/5..."
  curl -I http://demo.localhost && break || sleep 3
done
```

**If still 503:**
```bash
# 1. Check Ingress
kubectl get ingress -n tenant-demo
# ADDRESS should be "localhost"

# 2. Check backend
kubectl get endpoints podinfo -n tenant-demo
# Should show pod IPs (e.g. 10.244.0.5:9898)

# 3. Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 | grep demo.localhost

# 4. Manual port-forward (bypass Ingress)
kubectl port-forward -n tenant-demo svc/podinfo 9898:9898 &
curl http://localhost:9898
# If this works → Ingress problem
```

---

### **Problem 6: Cluster already exists**
```
Error: node(s) already exist for a cluster with the name "agent-k8s-local"
```

**Solution:**
```bash
# Delete old cluster
kind delete cluster --name agent-k8s-local

# Recreate
./setup-template/phase1/04-create-cluster/create.sh
```

---

### **Problem 7: kubectl commands slow (>5s)**

**Cause:** Cluster overloaded or Docker Desktop has too little RAM

**Solution:**
```bash
# 1. Check Docker stats
docker stats --no-stream

# 2. Check node resources
kubectl top nodes  # Requires metrics-server

# 3. Reduce replicas
kubectl scale deployment podinfo -n tenant-demo --replicas=1

# 4. More RAM for Docker (in Docker Desktop Settings)
# Settings → Resources → Memory: 4GB → 8GB
```

---

## 🧹 Cleanup & Reset

### **Scenario A: Delete cluster only (keep manifests)**
```bash
# Delete cluster
kind delete cluster --name agent-k8s-local

# Delete kind-config.yaml (will be recreated)
rm kind-config.yaml

# Restart at step 3
./setup-template/phase1/04-create-cluster/create.sh
./setup-template/phase1/05-deploy-ingress/deploy.sh
./setup-template/phase1/06-deploy-podinfo/deploy.sh
```

**Use case:** Cluster is broken, manifests are OK

---

### **Scenario B: Complete reset (incl. manifests)**
```bash
# Delete cluster
kind delete cluster --name agent-k8s-local

# Delete ALL generated files
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml

# ⚠️ WARNING: Git changes also gone!
git status  # Check what will be lost
git restore apps/  # If you want to restore Git version
```

**Use case:** Complete restart, regenerate manifests

---

### **Scenario C: Uninstall tools only**
```bash
# kind
sudo rm /usr/local/bin/kind

# kubectl
sudo rm /usr/local/bin/kubectl

# helm
sudo rm /usr/local/bin/helm

# flux
sudo rm /usr/local/bin/flux

# task
sudo snap remove task

# Docker (CAUTION: Deletes ALL containers/images!)
sudo apt purge -y docker-ce docker-ce-cli containerd.io
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

**Use case:** Completely clean up machine

---

### **Scenario D: Redeploy podinfo only**
```bash
# Delete deployment
kubectl delete namespace tenant-demo

# Redeploy
./setup-template/phase1/06-deploy-podinfo/deploy.sh

# Or manually:
kubectl create namespace tenant-demo
kubectl apply -k apps/podinfo/tenants/demo/
```

**Use case:** podinfo manifests changed, testing

---

## 📊 Performance Metrics (Reference)

### **Expected runtimes (tested on Ubuntu 22.04, 16GB RAM, SSD):**

```
Step 1: System Check               ~10s    (check only)
Step 2.1: Install Docker           ~90s    (incl. apt update)
  └─ REBOOT                        ~60s
Step 2.2: K8s Tools                ~40s    (download 5 binaries)
Step 3: Create cluster             ~17s    (kind create)
Step 4: Deploy Ingress             ~45s    (Helm install + pod ready)
Step 5: Deploy podinfo             ~12s    (kubectl apply + pods ready)
Step 6: Success validation         ~10s    (curl + tests)
──────────────────────────────────────────
TOTAL (without reboot):           ~3m 45s
TOTAL (with reboot):              ~4m 45s

Fast track (setup-phase1.sh):     ~1m 10s  (tools already installed)
```

### **Block details (for setup-phase1.sh):**
```
Block 1 (Check tools):      5s   ✅ (idempotent, skips if exists)
Block 2 (Structure):        2s   ✅ (mkdir -p)
Block 3 (Manifests):        5s   ⚠️  (git clone, overwrites apps/)
Block 4 (Cluster):         17s   ✅ (kind + retry logic)
Block 5 (Ingress):         28s   ✅ (Helm + wait)
Block 6 (podinfo):         13s   ✅ (kubectl apply + retry)
──────────────────────────────
TOTAL:                  1m 10s   (46/46 tests passed)
```

### **Why so fast?**
1. **kind instead of minikube** - Docker-based, no VM overhead
2. **Parallel deployments** - Ingress + podinfo not sequential
3. **Retry logic** - No manual waits needed
4. **Cached images** - Docker Hub images mostly preloaded

---

## 🚀 Next Steps - What Now?

### **1️⃣ Understand & adjust manifests**

#### **Scale podinfo (manually)**
```bash
# Replicas from 2 → 3
vim apps/podinfo/tenants/demo/patch.yaml
# Change: replicaCount: 3

# Redeploy
kubectl apply -k apps/podinfo/tenants/demo/

# Check
kubectl get pods -n tenant-demo
# Expected: 3 pods
```

#### **Commit your own changes to Git**
```bash
git add apps/podinfo/tenants/demo/patch.yaml
git commit -m "feat: scale podinfo to 3 replicas"
git push origin main
```

**🎯 Important for Phase 2:** Git = Single Source of Truth!

---

### **2️⃣ Deploy second app (nginx example)**

```bash
# Create namespace
kubectl create namespace my-app

# Deploy nginx
kubectl create deployment nginx --image=nginx:latest -n my-app
kubectl expose deployment nginx --port=80 --target-port=80 -n my-app

# Create Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: my-app
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

# Extend /etc/hosts
echo "127.0.0.1 myapp.localhost" | sudo tee -a /etc/hosts

# Test
curl http://myapp.localhost
# Expected: nginx default page HTML
```

---

### **3️⃣ Test multi-tenancy (production tenant)**

```bash
# Create second tenant
kubectl create namespace tenant-prod
kubectl label namespace tenant-prod tenant=prod

# Deploy podinfo-prod (3 replicas, prod.localhost)
kubectl create deployment podinfo-prod --image=ghcr.io/stefanprodan/podinfo:6.9.2 -n tenant-prod
kubectl set resources deployment podinfo-prod -n tenant-prod \
  --requests=cpu=100m,memory=64Mi \
  --limits=cpu=200m,memory=128Mi
kubectl scale deployment podinfo-prod -n tenant-prod --replicas=3
kubectl expose deployment podinfo-prod -n tenant-prod --port=9898 --target-port=9898

# Ingress for prod
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo-prod
  namespace: tenant-prod
spec:
  ingressClassName: nginx
  rules:
  - host: prod.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: podinfo-prod
            port:
              number: 9898
EOF

# Extend /etc/hosts
echo "127.0.0.1 prod.localhost" | sudo tee -a /etc/hosts

# Test
curl http://prod.localhost
# Expected: {"hostname":"podinfo-prod-xxx","version":"6.9.2"}
```

**Now you have 2 tenants:**
- http://demo.localhost (2 replicas)
- http://prod.localhost (3 replicas)

---

### **4️⃣ Prepare Phase 2 (GitOps with FluxCD)**

#### **What is Phase 2?**
- **GitOps:** Git push → Automatic deployment
- **Flux:** Reads Git repo → Syncs cluster
- **Production:** Azure AKS (cloud cluster)

#### **Test Flux locally:**
```bash
# Flux Bootstrap (connects Git with cluster)
flux bootstrap github \
  --owner=ADASK-B \
  --repository=agent-ready-k8s \
  --branch=main \
  --path=clusters/local \
  --personal

# What happens?
# 1. Flux installs itself in cluster
# 2. Creates GitRepository resource (points to this repo)
# 3. Creates Kustomization resource (watches apps/)
# 4. Deploys everything from Git automatically!

# Check
flux get kustomizations
flux get sources git

# Git push deploys automatically:
vim apps/podinfo/tenants/demo/patch.yaml
# replicaCount: 2 → 4
git commit -am "feat: scale to 4 replicas"
git push

# Flux reconciles (1-2 minutes)
flux reconcile kustomization flux-system --with-source
kubectl get pods -n tenant-demo -w
# Expected: 4 pods after ~30s
```

**📚 See:** `ROADMAP.md` → Blocks 10-13 (Phase 2 details)

---

### **5️⃣ Monitoring & Observability (Optional)**

#### **View logs:**
```bash
# podinfo logs
kubectl logs -n tenant-demo -l app=podinfo --tail=50 -f

# Ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 -f
```

#### **Install metrics-server:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for kind (insecure TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait
kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=metrics-server --timeout=60s

# Use
kubectl top nodes
kubectl top pods -n tenant-demo
```

#### **Install k9s (terminal UI):**
```bash
# Installation
curl -sS https://webinstall.dev/k9s | bash
source ~/.config/envman/PATH.env

# Start
k9s

# Navigation:
# :pods → All pods
# :svc → Services
# :ing → Ingresses
# / → Search
# l → Show logs
# d → Describe
# Ctrl+C → Exit
```

---

### **6️⃣ More learning resources**

#### **Kubernetes basics:**
- [Kubernetes Docs](https://kubernetes.io/docs/home/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

#### **GitOps with Flux:**
- [Flux Docs](https://fluxcd.io/flux/)
- [Flux Bootstrap Guide](https://fluxcd.io/flux/installation/bootstrap/)
- [Flux Kustomize Guide](https://fluxcd.io/flux/guides/kustomize/)

#### **kind best practices:**
- [kind Docs](https://kind.sigs.k8s.io/)
- [kind Ingress Guide](https://kind.sigs.k8s.io/docs/user/ingress/)

#### **podinfo (demo app):**
- [podinfo GitHub](https://github.com/stefanprodan/podinfo)
- [podinfo API Docs](https://github.com/stefanprodan/podinfo#api)

---

## 📚 More Documentation

- **Detailed Roadmap:** `ROADMAP.md` (Phase 1 + Phase 2 checklists)
- **Project Overview:** `README.md` (What is the project, for whom)
- **Script Reference:** `.github/copilot-instructions.md` (Table of contents for AI)
- **Phase 2 Planning:** `ROADMAP.md` → Blocks 10-13 (GitOps + AKS)

---

## 🎯 Summary

### **What did you build?**
✅ Local Kubernetes cluster (kind)  
✅ Ingress controller (nginx)  
✅ Demo app (podinfo v6.9.2)  
✅ Multi-tenant setup (tenant-demo namespace)  
✅ GitOps-ready structure (for Phase 2)

### **What can you do now?**
✅ Adjust manifests (apps/podinfo/)  
✅ Deploy your own apps (kubectl apply)  
✅ Run tests (setup-template/phase1/*/test.sh)  
✅ Start Phase 2 (Flux Bootstrap)

### **Next milestone:**
🎯 **Phase 2:** GitOps with Flux + Azure AKS deployment  
📅 **See:** `ROADMAP.md` → Blocks 10-13
