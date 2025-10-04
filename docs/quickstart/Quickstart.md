# 🚀 Quick Start - agent-ready-k8s

> **Szenario:** Frische Ubuntu-Maschine + VSCode + Git Clone → Running Demo  
> **Ziel:** http://demo.localhost zeigt podinfo v6.9.2 in ~2 Minuten  
> **Status:** Phase 1 (Lokal mit kind)

---

## ⚡ Fast Track - Vollautomatisch (1 Command)

**Wenn du bereits alle Tools installiert hast:**

```bash
cd ~/agent-ready-k8s
./setup-template/setup-phase1.sh
```

**Runtime:** ~1 Minute 10 Sekunden

**Was das Script macht:**
1. ✅ Prüft Tools (Docker, kind, kubectl, helm, flux)
2. ✅ Erstellt Ordnerstruktur (falls nicht vorhanden)
3. ⚠️  Clont FluxCD-Templates (**überschreibt apps/podinfo/**)
4. ✅ Erstellt kind-Cluster (agent-k8s-local)
5. ✅ Deployed ingress-nginx
6. ✅ Deployed podinfo
7. ✅ Führt 46 Tests aus

**⚠️ ACHTUNG:** Block 3 überschreibt `apps/podinfo/` mit FluxCD-Templates!  
→ Nur nutzen wenn du Manifeste zurücksetzen willst.

**Besser für Production:**  
→ Folge der manuellen Anleitung unten (überspringt Block 2+3, nutzt Git-Manifeste)

---

## � Nach Reboot - Cluster neu starten

**Situation:** Du hast deinen Rechner neugestartet, Cluster ist weg.

### **Was ist noch da?**
- ✅ Docker (läuft automatisch)
- ✅ Tools (kind, kubectl, helm, flux)
- ✅ Git-Repo (apps/, manifeste)
- ✅ Docker Images (gecached!)

### **Was fehlt?**
- ❌ kind-Cluster (Container gestoppt)
- ❌ Alle Pods (weg mit Cluster)

### **Quick Commands (Copy-Paste):**

#### **Option 1: Nur Cluster (Manifeste unverändert) - ~1 Min**
```bash
cd ~/agent-ready-k8s

# Cluster + Ingress + podinfo (nutzt Git-Manifeste)
./setup-template/phase1/04-create-cluster/create.sh  # ~17s
./setup-template/phase1/05-deploy-ingress/deploy.sh  # ~45s
./setup-template/phase1/06-deploy-podinfo/deploy.sh  # ~12s

# Test
curl http://demo.localhost
```

**Runtime:** ~1-2 Minuten (Images gecached!)  
**Nutzt:** Manifeste aus Git (NICHT überschrieben)

---

#### **Option 2: Vollautomatisch - ~1 Min 10s**
```bash
cd ~/agent-ready-k8s
./setup-template/setup-phase1.sh
```

**⚠️ ACHTUNG:** Überschreibt `apps/podinfo/` mit FluxCD-Templates!  
**Nur nutzen wenn:** Du Manifeste zurücksetzen willst

---

### **Warum so schnell nach Reboot?**
Docker hat Images gecached:
```bash
docker images
# kindest/node:v1.27.3       (500MB) ✅ gecached
# ingress-nginx/controller   (200MB) ✅ gecached
# podinfo:6.9.2              (20MB)  ✅ gecached
```

**Kein Re-Download nötig!** 🚀

---

### **Troubleshooting nach Reboot:**

#### **Docker läuft nicht?**
```bash
sudo systemctl status docker
# Falls inactive:
sudo systemctl start docker
```

#### **Tools nicht gefunden?**
```bash
kind version || echo "PATH Problem!"
# Fix:
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

#### **Port 80/443 belegt?**
```bash
sudo lsof -i :80
sudo lsof -i :443
# Apache stoppen:
sudo systemctl stop apache2
sudo systemctl disable apache2
```

---

**Details:** Siehe [Schritt 3-6](#️-schritt-3-kind-cluster-erstellen-30-sekunden) für manuelle Schritte

---

## �🗂️ Inhaltsverzeichnis

1. [Nach Reboot - Cluster neu starten](#-nach-reboot---cluster-neu-starten) ⭐ **Neu!**
2. [Was ist nach git clone schon da?](#-was-ist-nach-git-clone-schon-da)
3. [System-Anforderungen](#-system-anforderungen)
4. [Setup-Workflow](#-setup-workflow-von-null-zu-running)
5. [Schritt 1: System Check](#-schritt-1-system-check)
6. [Schritt 2: Tools installieren](#️-schritt-2-tools-installieren)
7. [Schritt 3: Cluster erstellen](#️-schritt-3-kind-cluster-erstellen-30-sekunden)
8. [Schritt 4: Ingress deployen](#-schritt-4-ingress-controller-deployen-45-sekunden)
9. [Schritt 5: podinfo deployen](#-schritt-5-podinfo-deployen-20-sekunden)
10. [Schritt 6: Erfolgskontrolle](#-schritt-6-erfolgskontrolle-30-sekunden)
11. [Troubleshooting](#-troubleshooting---häufige-probleme)
12. [Cleanup & Reset](#-cleanup--reset)
13. [Performance-Metriken](#-performance-metriken-referenz)
14. [Nächste Schritte](#-nächste-schritte---was-jetzt)

---

## 📦 Was ist nach `git clone` schon da?

### **✅ Bereits in Git (NICHT neu erstellen!):**
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

### **Übersicht:**
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

### **2.2 Kubernetes Tools installieren** (~60 Sekunden)

```bash
cd ~/agent-ready-k8s

# Nutze unser Script (installiert: kind, kubectl, helm, flux, task)
./setup-template/phase1/01-install-tools/install.sh
```

**Das Script installiert:**
- `kind` v0.20.0 → Lokaler K8s Cluster
- `kubectl` latest → Kubernetes CLI
- `helm` v3.19.0 → Package Manager
- `flux` v2.7.0 → GitOps Toolkit (für Phase 2)
- `task` v3.45.4 → Task Runner (optional)

**Test:**
```bash
kind version        # kind v0.20.0 go1.20.4 linux/amd64
kubectl version --client  # Client Version: v1.34.1
helm version        # version.BuildInfo{Version:"v3.19.0"}
flux version        # flux: v2.7.0
```

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

## ✅ Schritt 6: Erfolgskontrolle (~30 Sekunden)

### **6.1 Alle Pods laufen?**
```bash
kubectl get pods -A
```

**Erwartung:**
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

**Alle müssen `Running` + `1/1 Ready` sein!**

---

### **6.2 HTTP Endpoint antwortet?**

#### **Option A: curl (Terminal)**
```bash
curl http://demo.localhost
```

**Erwartung:**
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
Öffne: **http://demo.localhost**

**Erwartung:**
- Blaues UI mit podinfo Logo
- Version: 6.9.2
- Hostname zeigt Pod-Name
- Tabs: Home, Status, Metrics, Swagger

#### **Option C: Health Check**
```bash
curl http://demo.localhost/healthz
```

**Erwartung:**
```json
{"status":"ok"}
```

---

### **6.3 Tests automatisch laufen lassen**
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

**Gesamt: 24/24 Tests sollten bestehen!**

---

### **6.4 Was wenn HTTP 503?**

**Problem:**
```bash
curl http://demo.localhost
# <html>
# <head><title>503 Service Temporarily Unavailable</title></head>
```

**Ursache:** Ingress-Controller propagiert noch (10-15s nach Pod Ready)

**Lösung: Retry mit Backoff**
```bash
for i in {1..5}; do
  echo "Attempt $i/5..."
  curl -I http://demo.localhost && break || sleep 3
done
```

**Falls immer noch 503:**
```bash
# Prüfe Ingress Status
kubectl describe ingress podinfo -n tenant-demo

# Prüfe Controller Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Prüfe /etc/hosts
grep demo.localhost /etc/hosts || echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts
```

---

## 🔍 Troubleshooting - Häufige Probleme

### **Problem 1: Docker Permission Denied**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Ursache:** User nicht in `docker` Gruppe

**Lösung:**
```bash
sudo usermod -aG docker $USER
newgrp docker  # Temporär, oder:
sudo reboot    # Persistent
```

**Test:**
```bash
docker ps  # Sollte KEINE Permission Error mehr zeigen
```

---

### **Problem 2: Port 80 already in use**
```
Error: failed to create cluster: ... address already in use
```

**Ursache:** Anderer Prozess nutzt Port 80/443 (z.B. Apache, nginx)

**Lösung:**
```bash
# Finde Prozess
sudo lsof -i :80
sudo lsof -i :443

# Beispiel: Apache stoppen
sudo systemctl stop apache2
sudo systemctl disable apache2  # Autostart deaktivieren

# Cluster neu erstellen
kind delete cluster --name agent-k8s-local
./setup-template/phase1/04-create-cluster/create.sh
```

---

### **Problem 3: Pods bleiben in Pending/ContainerCreating**
```bash
kubectl get pods -A
# STATUS: Pending oder ContainerCreating (>1 Minute)
```

**Ursache:** Image-Download läuft noch (Docker Hub Rate Limit oder langsame Verbindung)

**Lösung:**
```bash
# Warte bis Pods ready (max 2 Minuten)
kubectl wait --for=condition=ready pod --all -n ingress-nginx --timeout=120s
kubectl wait --for=condition=ready pod --all -n tenant-demo --timeout=120s

# Prüfe Events
kubectl get events -n tenant-demo --sort-by='.lastTimestamp'

# Prüfe Pod Details
kubectl describe pod -n tenant-demo podinfo-xxxxx
```

**Falls Docker Hub Rate Limit:**
```
Warning  Failed     ... Error: ImagePullBackOff ... toomanyrequests
```
→ Warten 5-10 Minuten, dann:
```bash
kubectl rollout restart deployment podinfo -n tenant-demo
```

---

### **Problem 4: demo.localhost nicht erreichbar**
```bash
curl http://demo.localhost
# curl: (6) Could not resolve host: demo.localhost
```

**Ursache:** `/etc/hosts` fehlt Eintrag

**Lösung:**
```bash
# Eintrag hinzufügen
echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts

# Prüfen
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

**Ursache:** Ingress-Controller propagiert noch (~10-15s nach Pod Ready)

**Lösung:**
```bash
# Retry mit Backoff
for i in {1..5}; do
  echo "Attempt $i/5..."
  curl -I http://demo.localhost && break || sleep 3
done
```

**Falls immer noch 503:**
```bash
# 1. Prüfe Ingress
kubectl get ingress -n tenant-demo
# ADDRESS sollte "localhost" sein

# 2. Prüfe Backend
kubectl get endpoints podinfo -n tenant-demo
# Sollte Pod-IPs zeigen (z.B. 10.244.0.5:9898)

# 3. Prüfe Controller Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 | grep demo.localhost

# 4. Manual Port-Forward (Bypass Ingress)
kubectl port-forward -n tenant-demo svc/podinfo 9898:9898 &
curl http://localhost:9898
# Falls das funktioniert → Ingress-Problem
```

---

### **Problem 6: Cluster existiert schon**
```
Error: node(s) already exist for a cluster with the name "agent-k8s-local"
```

**Lösung:**
```bash
# Alten Cluster löschen
kind delete cluster --name agent-k8s-local

# Neu erstellen
./setup-template/phase1/04-create-cluster/create.sh
```

---

### **Problem 7: kubectl Befehle langsam (>5s)**

**Ursache:** Cluster überlastet oder Docker Desktop zu wenig RAM

**Lösung:**
```bash
# 1. Prüfe Docker Stats
docker stats --no-stream

# 2. Prüfe Node Resources
kubectl top nodes  # Benötigt metrics-server

# 3. Reduziere Replicas
kubectl scale deployment podinfo -n tenant-demo --replicas=1

# 4. Mehr RAM für Docker (in Docker Desktop Settings)
# Settings → Resources → Memory: 4GB → 8GB
```

---

## 🧹 Cleanup & Reset

### **Szenario A: Nur Cluster löschen (Manifeste behalten)**
```bash
# Cluster löschen
kind delete cluster --name agent-k8s-local

# kind-config.yaml löschen (wird neu erstellt)
rm kind-config.yaml

# Neu starten bei Schritt 3
./setup-template/phase1/04-create-cluster/create.sh
./setup-template/phase1/05-deploy-ingress/deploy.sh
./setup-template/phase1/06-deploy-podinfo/deploy.sh
```

**Use Case:** Cluster ist kaputt, Manifeste sind OK

---

### **Szenario B: Komplett zurücksetzen (inkl. Manifeste)**
```bash
# Cluster löschen
kind delete cluster --name agent-k8s-local

# ALLE generierten Dateien löschen
rm -rf apps/ clusters/ infrastructure/ policies/ kind-config.yaml

# ⚠️ ACHTUNG: Git-Änderungen auch weg!
git status  # Prüfe was verloren geht
git restore apps/  # Falls du Git-Version wiederherstellen willst
```

**Use Case:** Kompletter Neustart, Manifeste neu generieren

---

### **Szenario C: Nur Tools deinstallieren**
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

# Docker (VORSICHT: Löscht ALLE Container/Images!)
sudo apt purge -y docker-ce docker-ce-cli containerd.io
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

**Use Case:** Maschine komplett aufräumen

---

### **Szenario D: Nur podinfo neu deployen**
```bash
# Deployment löschen
kubectl delete namespace tenant-demo

# Neu deployen
./setup-template/phase1/06-deploy-podinfo/deploy.sh

# Oder manuell:
kubectl create namespace tenant-demo
kubectl apply -k apps/podinfo/tenants/demo/
```

**Use Case:** podinfo-Manifeste geändert, testen

---

## 📊 Performance-Metriken (Referenz)

### **Erwartete Runtimes (getestet auf Ubuntu 22.04, 16GB RAM, SSD):**

```
Schritt 1: System Check             ~10s    (nur Prüfung)
Schritt 2.1: Docker installieren    ~90s    (inkl. apt update)
  └─ REBOOT                         ~60s
Schritt 2.2: K8s Tools              ~40s    (5 Binaries downloaden)
Schritt 3: Cluster erstellen        ~17s    (kind create)
Schritt 4: Ingress deployen         ~45s    (Helm install + Pod ready)
Schritt 5: podinfo deployen         ~12s    (kubectl apply + Pods ready)
Schritt 6: Erfolgskontrolle         ~10s    (curl + Tests)
──────────────────────────────────────────
GESAMT (ohne Reboot):              ~3m 45s
GESAMT (mit Reboot):               ~4m 45s

Schneller Weg (setup-phase1.sh):   ~1m 10s  (Tools schon installiert)
```

### **Block-Details (für setup-phase1.sh):**
```
Block 1 (Tools prüfen):      5s   ✅ (idempotent, überspringt wenn vorhanden)
Block 2 (Struktur):          2s   ✅ (mkdir -p)
Block 3 (Manifeste):         5s   ⚠️  (git clone, überschreibt apps/)
Block 4 (Cluster):          17s   ✅ (kind + retry-logic)
Block 5 (Ingress):          28s   ✅ (Helm + wait)
Block 6 (podinfo):          13s   ✅ (kubectl apply + retry)
──────────────────────────────
GESAMT:                  1m 10s   (46/46 Tests bestanden)
```

### **Warum so schnell?**
1. **kind statt minikube** - Docker-basiert, kein VM-Overhead
2. **Parallel Deployments** - Ingress + podinfo nicht sequenziell
3. **Retry-Logik** - Keine manuellen Waits nötig
4. **Cached Images** - Docker Hub Images meist vorgeladen

---

## 🚀 Nächste Schritte - Was jetzt?

### **1️⃣ Manifeste verstehen & anpassen**

#### **podinfo skalieren (manuell)**
```bash
# Replicas von 2 → 3
vim apps/podinfo/tenants/demo/patch.yaml
# Ändere: replicaCount: 3

# Neu deployen
kubectl apply -k apps/podinfo/tenants/demo/

# Prüfen
kubectl get pods -n tenant-demo
# Expected: 3 Pods
```

#### **Eigene Änderungen in Git commiten**
```bash
git add apps/podinfo/tenants/demo/patch.yaml
git commit -m "feat: scale podinfo to 3 replicas"
git push origin main
```

**🎯 Wichtig für Phase 2:** Git = Single Source of Truth!

---

### **2️⃣ Zweite App deployen (nginx Beispiel)**

```bash
# Namespace erstellen
kubectl create namespace my-app

# nginx deployen
kubectl create deployment nginx --image=nginx:latest -n my-app
kubectl expose deployment nginx --port=80 --target-port=80 -n my-app

# Ingress erstellen
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

# /etc/hosts erweitern
echo "127.0.0.1 myapp.localhost" | sudo tee -a /etc/hosts

# Testen
curl http://myapp.localhost
# Expected: nginx Default-Page HTML
```

---

### **3️⃣ Multi-Tenancy testen (Production Tenant)**

```bash
# Zweiten Tenant erstellen
kubectl create namespace tenant-prod
kubectl label namespace tenant-prod tenant=prod

# podinfo-prod deployen (3 Replicas, prod.localhost)
kubectl create deployment podinfo-prod --image=ghcr.io/stefanprodan/podinfo:6.9.2 -n tenant-prod
kubectl set resources deployment podinfo-prod -n tenant-prod \
  --requests=cpu=100m,memory=64Mi \
  --limits=cpu=200m,memory=128Mi
kubectl scale deployment podinfo-prod -n tenant-prod --replicas=3
kubectl expose deployment podinfo-prod -n tenant-prod --port=9898 --target-port=9898

# Ingress für prod
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

# /etc/hosts erweitern
echo "127.0.0.1 prod.localhost" | sudo tee -a /etc/hosts

# Testen
curl http://prod.localhost
# Expected: {"hostname":"podinfo-prod-xxx","version":"6.9.2"}
```

**Jetzt hast du 2 Tenants:**
- http://demo.localhost (2 Replicas)
- http://prod.localhost (3 Replicas)

---

### **4️⃣ Phase 2 vorbereiten (GitOps mit FluxCD)**

#### **Was ist Phase 2?**
- **GitOps:** Git-Push → Automatisches Deployment
- **Flux:** Liest Git-Repo → Synchronisiert Cluster
- **Production:** Azure AKS (Cloud-Cluster)

#### **Lokal Flux testen:**
```bash
# Flux Bootstrap (verbindet Git mit Cluster)
flux bootstrap github \
  --owner=ADASK-B \
  --repository=agent-ready-k8s \
  --branch=main \
  --path=clusters/local \
  --personal

# Was passiert?
# 1. Flux installed sich selbst in Cluster
# 2. Erstellt GitRepository-Ressource (pointed auf dieses Repo)
# 3. Erstellt Kustomization-Ressource (watched apps/)
# 4. Deployed alles aus Git automatisch!

# Prüfen
flux get kustomizations
flux get sources git

# Git-Push deployed automatisch:
vim apps/podinfo/tenants/demo/patch.yaml
# replicaCount: 2 → 4
git commit -am "feat: scale to 4 replicas"
git push

# Flux reconciled (1-2 Minuten)
flux reconcile kustomization flux-system --with-source
kubectl get pods -n tenant-demo -w
# Expected: 4 Pods nach ~30s
```

**📚 Siehe:** `ROADMAP.md` → Block 10-13 (Phase 2 Details)

---

### **5️⃣ Monitoring & Observability (Optional)**

#### **Logs anschauen:**
```bash
# podinfo Logs
kubectl logs -n tenant-demo -l app=podinfo --tail=50 -f

# Ingress Logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 -f
```

#### **Metrics-Server installieren:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch für kind (insecure TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Warten
kubectl wait --for=condition=ready pod -n kube-system -l k8s-app=metrics-server --timeout=60s

# Nutzen
kubectl top nodes
kubectl top pods -n tenant-demo
```

#### **k9s installieren (Terminal UI):**
```bash
# Installation
curl -sS https://webinstall.dev/k9s | bash
source ~/.config/envman/PATH.env

# Starten
k9s

# Navigation:
# :pods → Alle Pods
# :svc → Services
# :ing → Ingresses
# / → Suchen
# l → Logs anzeigen
# d → Describe
# Ctrl+C → Exit
```

---

### **6️⃣ Weitere Lern-Ressourcen**

#### **Kubernetes Basics:**
- [Kubernetes Docs](https://kubernetes.io/docs/home/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

#### **GitOps mit Flux:**
- [Flux Docs](https://fluxcd.io/flux/)
- [Flux Bootstrap Guide](https://fluxcd.io/flux/installation/bootstrap/)
- [Flux Kustomize Guide](https://fluxcd.io/flux/guides/kustomize/)

#### **kind Best Practices:**
- [kind Docs](https://kind.sigs.k8s.io/)
- [kind Ingress Guide](https://kind.sigs.k8s.io/docs/user/ingress/)

#### **podinfo (Demo-App):**
- [podinfo GitHub](https://github.com/stefanprodan/podinfo)
- [podinfo API Docs](https://github.com/stefanprodan/podinfo#api)

---

## 📚 Weitere Dokumentation

- **Detaillierte Roadmap:** `ROADMAP.md` (Phase 1 + Phase 2 Checklisten)
- **Projekt-Übersicht:** `README.md` (Was ist das Projekt, für wen)
- **Script-Referenz:** `.github/copilot-instructions.md` (Inhaltsverzeichnis für AI)
- **Phase 2 Planning:** `ROADMAP.md` → Block 10-13 (GitOps + AKS)

---

## 🎯 Zusammenfassung

### **Was hast du gebaut?**
✅ Lokalen Kubernetes-Cluster (kind)  
✅ Ingress-Controller (nginx)  
✅ Demo-App (podinfo v6.9.2)  
✅ Multi-Tenant Setup (tenant-demo Namespace)  
✅ GitOps-Ready Struktur (für Phase 2)

### **Was kannst du jetzt?**
✅ Manifeste anpassen (apps/podinfo/)  
✅ Eigene Apps deployen (kubectl apply)  
✅ Tests laufen (setup-template/phase1/*/test.sh)  
✅ Phase 2 starten (Flux Bootstrap)

### **Nächster Milestone:**
🎯 **Phase 2:** GitOps mit Flux + Azure AKS Deployment  
📅 **Siehe:** `ROADMAP.md` → Block 10-13
