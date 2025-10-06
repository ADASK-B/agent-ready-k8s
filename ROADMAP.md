# 🗺️ Template Setup Roadmap

> **Ziel Phase 1:** 100% lauffähige Demo-Template auf der wir lokal entwickeln können  
> **Ziel Phase 2:** Git-Workflow + automatisches AKS-Deployment (später)

---

## 🎯 Phasen-Übersicht

### **Phase 1: Lokale Entwicklungsumgebung** ⏱️ ~2-3h
**Ziel:** Template läuft komplett lokal, wir können alle Projekte darauf aufsetzen

```
Laptop (Ubuntu)
    ↓
Tools installieren (Docker, kind, kubectl, Helm, ...)
    ↓
kind-Cluster starten
    ↓
podinfo deployen
    ↓
✅ http://demo.localhost läuft im Browser
```

**→ Danach:** Lokal entwickeln, testen, iterieren (OHNE Git/Cloud)

---

### **Phase 2: Git-Workflow + AKS** ⏱️ später
**Ziel:** Code committen → automatisch in Azure deployen

```
Laptop (lokal entwickelt)
    ↓
git commit & push
    ↓
GitHub Actions (Security-Scans, Build)
    ↓
Argo CD in AKS zieht Update
    ↓
✅ App läuft in Azure Cloud
```

**→ Kommt erst wenn Phase 1 100% funktioniert!**

---

## 📋 Checkliste: Phase 1 (Lokale Template)

> **🚀 Quick Start:** Komplette Automation mit `./setup-template/setup-phase1.sh`  
> **⏱️ Runtime:** ~1-2 Minuten (vollautomatisch, alle 6 Blöcke)  
> **Ergebnis:** Running demo at `http://demo.localhost`  
> **✅ Status:** ABGESCHLOSSEN (46/46 Tests bestanden)

### **Block 1: Tool-Installation (Ubuntu)** ⏱️ ~30 min → ✅ **ERLEDIGT** (7/7 Tests)

- [x] **1.1 Docker Engine CE installieren** ✅
  ```bash
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  ```
  - **Test:** `docker run hello-world` ✅
  - ⚠️ **Reboot erforderlich!** → `sudo reboot`
  - **Installiert:** Docker version 28.5.0

- [x] **1.2 kind installieren** (Kubernetes in Docker) ✅
  ```bash
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  ```
  - **Test:** `kind version` ✅
  - **Installiert:** kind v0.20.0

- [x] **1.3 kubectl installieren** ✅
  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  ```
  - **Test:** `kubectl version --client` ✅
  - **Installiert:** Client Version: v1.34.1

- [x] **1.4 Argo CD CLI installieren** ✅
  ```bash
  ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  curl -sSL -o /tmp/argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
  sudo install -m 555 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
  rm /tmp/argocd-linux-amd64
  ```
  - **Test:** `argocd version --client` ✅
  - **Installiert:** argocd: v2.13+ (latest)

- [x] **1.5 Helm installieren** ✅
  ```bash
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```
  - **Test:** `helm version` ✅
  - **Installiert:** v3.19.0

- [x] **1.6 Task installieren** (Makefile-Alternative) ✅
  ```bash
  sudo snap install task --classic
  ```
  - **Test:** `task --version` ✅
  - **Installiert:** 3.45.4

**📊 Block 1 Automation:**
- **Script:** `./setup-template/phase1/01-install-tools/install.sh`
- **Test:** `./setup-template/phase1/01-install-tools/test.sh`
- **Runtime:** ~5 Sekunden (alle Tools bereits vorhanden)

---

### **Block 2: Security Tools installieren** ⏱️ ~15 min → ⏸️ **PHASE 2** (Optional)

> **Hinweis:** Security Tools werden für Phase 2 (CI/CD Pipeline) benötigt, nicht für lokale Entwicklung.

- [ ] **2.1 Trivy installieren** (Container-Scanner)
  ```bash
  sudo apt-get install wget apt-transport-https gnupg lsb-release
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
  sudo apt update
  sudo apt install trivy
  ```
  - **Test:** `trivy version`

- [ ] **2.2 Gitleaks installieren** (Secret-Scanner)
  ```bash
  wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
  tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
  sudo mv gitleaks /usr/local/bin/
  rm gitleaks_8.18.0_linux_x64.tar.gz
  ```
  - **Test:** `gitleaks version`

- [ ] **2.3 kubeconform installieren** (K8s-Validator)
  ```bash
  wget https://github.com/yannh/kubeconform/releases/download/v0.6.3/kubeconform-linux-amd64.tar.gz
  tar -xzf kubeconform-linux-amd64.tar.gz
  sudo mv kubeconform /usr/local/bin/
  rm kubeconform-linux-amd64.tar.gz
  ```
  - **Test:** `kubeconform -v`

- [ ] **2.4 pre-commit installieren** (Git Hooks)
  ```bash
  sudo apt install python3-pip -y
  pip3 install pre-commit
  ```
  - **Test:** `pre-commit --version`

---

### **Block 3: Projekt-Struktur erstellen** ⏱️ ~20 min → ✅ **ERLEDIGT** (10/10 Tests)

- [x] **3.1 Basis-Ordnerstruktur anlegen** ✅
  ```bash
  mkdir -p apps/podinfo/{base,tenants/demo}
  mkdir -p clusters/{local,production}/{flux-system,tenants}
  mkdir -p infrastructure/{sources,controllers/{ingress-nginx,sealed-secrets}}
  mkdir -p policies/{namespace-template,conftest}
  mkdir -p setup-template/utils
  mkdir -p docs
  ```
  - **Erstellt:** Alle GitOps-Ordner vorhanden

- [x] **3.2 kind-config.yaml erstellen** (im Root) ✅
  ```yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
  ```
  - **Erstellt:** kind-config.yaml mit Port-Mappings 80/443

- [x] **3.3 .gitignore erstellen** ✅
  ```gitignore
  # Secrets
  .env
  .env.local
  *.key
  *.pem
  kubeconfig
  *-secret.yaml
  !sealed-secret.yaml
  
  # Build
  node_modules/
  dist/
  build/
  
  # IDE
  .vscode/
  .idea/
  
  # Temp
  *.tar.gz
  *.log
  ```
  - **Erstellt:** .gitignore vorhanden

- [ ] **3.4 Taskfile.yml erstellen** (Agent-Commands) → ⏸️ **SPÄTER**
  - Siehe separates Template unten ⬇️

**📊 Block 3 Automation:**
- **Script:** `./setup-template/phase1/02-create-structure/create.sh`
- **Test:** `./setup-template/phase1/02-create-structure/test.sh`
- **Runtime:** ~2 Sekunden

---

### **Block 4: Template-Struktur von Best-Practice-Repos übernehmen** ⏱️ ~25 min → ✅ **ERLEDIGT** (5/5 Tests)

> **Ziel:** Flux Example + podinfo + Lizenzen korrekt integrieren

**📦 Was holen wir woher?**

| Quelle | Datei/Ordner im Original | Ziel in unserem Projekt | Zweck | Status |
|--------|--------------------------|-------------------------|-------|--------|
| **podinfo Repo** | `kustomize/` | `apps/podinfo/base/` | Standard K8s Manifests (Deployment, Service) | ✅ |
| **podinfo Repo** | `kustomize/` | `apps/podinfo/tenants/demo/` | Tenant-spezifische Overlays (Ingress) | ✅ |
| **Argo CD Apps** | (manuell erstellt) | `clusters/local/` | Argo CD Applications für lokalen Cluster | ⏸️ Phase 2 |
| **Argo CD Apps** | (manuell erstellt) | `infrastructure/` | Ingress-Nginx, Sealed Secrets als Argo Apps | ⏸️ Phase 2 |
| **podinfo Helm Chart** | (via `helm repo add`) | Deployed in `tenant-demo` Namespace | Demo-Webserver für Tests | ✅ |

**✅ Nach Block 4:** Alle GitOps-Manifeste (HelmRelease, Kustomization) liegen bereit

---

#### **Automatisches Setup** ⏱️ ~5 Sekunden → ✅ **ERLEDIGT**

- [x] **4.1 Setup-Skript ausgeführt** ✅
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  chmod +x setup-template/phase1/03-clone-templates/clone.sh
  ./setup-template/phase1/03-clone-templates/clone.sh
  ```
  
  **Das Skript macht automatisch:**
  - Clont Flux Example-Repo ✅
  - Kopiert relevante Dateien (podinfo, Kustomize-Struktur) ✅
  - Fallback: Erstellt tenant manifests (staging nicht im Repo vorhanden) ✅
  - Räumt Temp-Dateien auf ✅

- [x] **4.2 Ergebnis geprüft** ✅
  ```bash
  tree -L 3 apps/podinfo
  # apps/podinfo/
  # ├── base/
  # │   ├── helmrelease.yaml
  # │   ├── kustomization.yaml
  # │   ├── namespace.yaml
  # │   └── repository.yaml
  # └── tenants/
  #     └── demo/
  #         ├── kustomization.yaml
  #         └── patch.yaml
  ```

**📊 Block 4 Automation:**
- **Script:** `./setup-template/phase1/03-clone-templates/clone.sh`
- **Test:** `./setup-template/phase1/03-clone-templates/test.sh`
- **Runtime:** ~5 Sekunden
- **Hinweis:** Erstellt standard Kubernetes Manifeste (Deployment, Service, Ingress)

---

#### **⏸️ Option B: Manuelle Setup** (nicht benötigt, Automation funktioniert)

- [ ] **4.3 podinfo-Repo clonen** (für Manifest-Beispiele)
  ```bash
  cd /tmp
  git clone --depth 1 https://github.com/stefanprodan/podinfo.git
  cd podinfo
  tree -L 3  # Struktur ansehen
  ```

- [ ] **4.4 podinfo-Manifeste erstellen**
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  
  # Standard Kubernetes Manifeste erstellen
  # Deployment, Service, Ingress für podinfo
  # (siehe Fallback-Sektion unten für Beispiele)
  ```

- [ ] **4.5 Kustomization-Files anpassen**
  ```bash
  # Falls staging → local Anpassung nötig
  find apps/podinfo -type f -name "*.yaml" -exec sed -i 's/staging/local/g' {} \;
  find clusters/local -type f -name "*.yaml" -exec sed -i 's/staging/local/g' {} \;
  ```

- [ ] **4.6 Lizenz-Hinweise erstellen**
  ```bash
  cat > LICENSE-3RD-PARTY.md << 'EOF'
  # Third-Party Licenses & Attributions

  This project uses code and patterns from the following open-source projects:

  ## Argo CD
  - **Source:** https://github.com/argoproj/argo-cd
  - **License:** Apache-2.0
  - **Copyright:** Argo Project Authors
  - **Usage:** GitOps continuous delivery tool for Kubernetes

  ## podinfo (Demo Application)
  - **Source:** https://github.com/stefanprodan/podinfo
  - **License:** Apache-2.0
  - **Copyright:** Stefan Prodan
  - **Usage:** Demo workload for testing Kubernetes deployments

  ## AKS Baseline Automation (Phase 2)
  - **Source:** https://github.com/Azure/aks-baseline-automation
  - **License:** MIT
  - **Copyright:** Microsoft Corporation
  - **Usage:** Azure Kubernetes Service best practices (Phase 2 only)

  ## helm/kind-action (Phase 2)
  - **Source:** https://github.com/helm/kind-action
  - **License:** Apache-2.0
  - **Copyright:** The Helm Authors
  - **Usage:** CI/CD testing with ephemeral kind clusters (Phase 2 only)

  ---

  **Note:** All third-party components retain their original licenses.
  This project (agent-ready-k8s) is licensed under MIT (see LICENSE).
  EOF
  ```

- [ ] **4.7 Git-History bereinigen**
  ```bash
  # Temp-Repos löschen (keine .git-History übernehmen!)
  rm -rf /tmp/podinfo
  rm -rf /tmp/aks-baseline-automation
  ```

- [ ] **4.8 README Credits hinzufügen**
  ```bash
  # Am Ende von README.md ergänzen:
  cat >> README.md << 'EOF'

  ## 🙏 Credits & Attributions

  This template is built upon best practices from:
  - [Argo CD](https://github.com/argoproj/argo-cd) - GitOps continuous delivery (Apache-2.0)
  - [podinfo](https://github.com/stefanprodan/podinfo) by Stefan Prodan (Apache-2.0)
  - [AKS Baseline](https://github.com/Azure/aks-baseline-automation) by Microsoft (MIT)

  See [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) for full attribution.
  EOF
  ```

---

#### **Fallback: podinfo manuell erstellen (Standard K8s Manifeste)** ⏱️ ~10 min

- [ ] **4.9 podinfo Deployment erstellen**
  ```bash
  cat > apps/podinfo/base/deployment.yaml << 'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: podinfo
    namespace: tenant-demo
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: podinfo
    template:
      metadata:
        labels:
          app: podinfo
      spec:
        containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.9.2
          ports:
          - containerPort: 9898
            name: http
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: podinfo
    namespace: tenant-demo
  spec:
    selector:
      app: podinfo
    ports:
    - port: 9898
      targetPort: 9898
  EOF
  ```

- [ ] **4.10 Ingress erstellen**
  ```bash
  cat > apps/podinfo/tenants/demo/ingress.yaml << 'EOF'
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: podinfo
    namespace: tenant-demo
  spec:
    ingressClassName: nginx
    rules:
    - host: demo.localhost
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: podinfo
              port:
                number: 9898
  EOF
  ```

---

### **Block 5: Lokalen kind-Cluster erstellen** ⏱️ ~10 min → ✅ **ERLEDIGT** (5/5 Tests)

- [x] **5.1 kind-Cluster gestartet** ✅
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  kind create cluster --name agent-k8s-local --config=kind-config.yaml
  ```
  - **Test:** `kubectl cluster-info` ✅
  - **Erstellt:** Cluster "agent-k8s-local" mit Kubernetes v1.27.3

- [x] **5.2 Cluster-Context gesetzt** ✅
  ```bash
  kubectl config use-context kind-agent-k8s-local
  kubectl get nodes
  ```
  - **Status:** 1 Node Ready

- [x] **5.3 /etc/hosts eingetragen** ✅ (automatisch beim ersten Setup)
  ```bash
  echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts
  ```
  - **Erreichbar:** http://demo.localhost

**📊 Block 5 Automation:**
- **Script:** `./setup-template/phase1/04-create-cluster/create.sh`
- **Test:** `./setup-template/phase1/04-create-cluster/test.sh`
- **Runtime:** ~17 Sekunden
- **Fix:** Retry-Logik für System Pods (3 Versuche, 2s Sleep)

---

### **Block 6: Infrastructure deployen** ⏱️ ~15 min → ✅ **ERLEDIGT** (7/7 Tests)

- [x] **6.1 Ingress-Nginx installiert** ✅
  ```bash
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostPort.enabled=true \
    --set controller.service.type=NodePort
  ```
  - **Test:** `kubectl get pods -n ingress-nginx` ✅
  - **Status:** Controller Pod Running (1/1)
  - **Fix:** hostPort statt NodePort ports (kind-Kompatibilität)

  - [ ] **6.2 Sealed Secrets Controller installieren** → ⏸️ **PHASE 2** (GitOps benötigt)
  ```bash
  kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
  tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
  sudo mv kubeseal /usr/local/bin/
  rm kubeseal-0.24.0-linux-amd64.tar.gz
  ```
  - **Test:** `kubectl get pods -n kube-system | grep sealed-secrets`

- [x] **6.3 Warten bis Ingress läuft** ✅
  ```bash
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
  ```
  - **Status:** Controller Ready nach ~20 Sekunden

**📊 Block 6 Automation:**
- **Script:** `./setup-template/phase1/05-deploy-ingress/deploy.sh`
- **Test:** `./setup-template/phase1/05-deploy-ingress/test.sh`
- **Runtime:** ~20 Sekunden
- **Service:** NodePort (30255/TCP, 30246/TCP)

---

### **Block 7: Demo-App (podinfo) deployen** ⏱️ ~20 min → ✅ **ERLEDIGT** (12/12 Tests)

- [x] **7.1 Namespace erstellt** ✅
  ```bash
  kubectl create namespace tenant-demo
  kubectl label namespace tenant-demo tenant=demo
  ```
  - **Erstellt:** Namespace "tenant-demo" mit Label

- [x] **7.2 podinfo via Helm deployed** ✅
  ```bash
  helm repo add podinfo https://stefanprodan.github.io/podinfo
  helm install podinfo podinfo/podinfo \
    --namespace tenant-demo \
    --set replicaCount=2 \
    --set ingress.enabled=true \
    --set ingress.hosts[0].host=demo.localhost \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix
  ```
  - **Deployed:** podinfo v6.9.2 (2 Replicas)

- [x] **7.3 Deployment-Status geprüft** ✅
  ```bash
  kubectl get pods -n tenant-demo
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=podinfo -n tenant-demo --timeout=300s
  ```
  - **Status:** 2/2 Pods Running

- [x] **7.4 Ingress getestet** ✅
  ```bash
  kubectl get ingress -n tenant-demo
  curl http://demo.localhost
  ```
  - **HTTP 200:** JSON Response mit podinfo Daten

**📊 Block 7 Automation:**
- **Script:** `./setup-template/phase1/06-deploy-podinfo/deploy.sh`
- **Test:** `./setup-template/phase1/06-deploy-podinfo/test.sh`
- **Runtime:** ~8 Sekunden
- **Fix:** HTTP Test mit 5 Retries (3s Sleep) für Ingress-Propagation
- **URL:** http://demo.localhost

---

### **Block 8: Finaler Funktionstest** ⏱️ ~10 min → ✅ **ERLEDIGT** (in Block 7 integriert)

- [x] **8.1 Browser-Test** ✅
  - Browser öffnen: `http://demo.localhost`
  - ✅ Zeigt podinfo-UI (Version, Hostname, etc.)

- [x] **8.2 API-Test** ✅
  ```bash
  curl http://demo.localhost/healthz
  # Antwort: {"status":"ok"}
  ```

- [x] **8.3 Logs geprüft** ✅
  ```bash
  kubectl logs -l app.kubernetes.io/name=podinfo -n tenant-demo --tail=50
  ```

- [ ] **8.4 Security-Scan (Beispiel)** → ⏸️ **PHASE 2**
  ```bash
  trivy image stefanprodan/podinfo:latest --severity HIGH,CRITICAL
  ```

---

### **Block 9: Dokumentation vervollständigen** ⏱️ ~15 min → 🚧 **IN ARBEIT**

- [x] **9.1 ROADMAP.md aktualisiert** ✅ (dieses Dokument)
  - Quick Start mit neuem Script-Pfad
  - Alle erledigten Aufgaben markiert
  - Runtime-Statistiken hinzugefügt

- [ ] **9.2 README.md anpassen** → 🚧 **TODO**
  - Quick Start aktualisieren (mit podinfo-Beispiel)
  - Neuen Script-Pfad: `./setup-template/setup-phase1.sh`
  - Runtime: ~1-2 Minuten statt 20-30 Minuten
  - Screenshots hinzufügen (optional)

- [ ] **9.3 SETUP.md erstellen** (in `docs/`) → 🚧 **TODO**
  - Detaillierte Tool-Installationsanleitung
  - Troubleshooting-Tipps (Docker group, Timing-Issues)
  - phase1/ Struktur erklären

- [ ] **9.4 Taskfile.yml erstellen/testen** → ⏸️ **PHASE 2**
  ```bash
  task cluster:info
  task tenant:logs TENANT=demo
  ```

---

## ✅ Erfolgskriterien Phase 1 (Abnahmetest)

**🎯 Phase 1 ist fertig wenn:**
- ✅ Alle Tools installiert (Docker, kind, kubectl, Helm, Flux, Task) → **ERLEDIGT**
- ✅ kind-Cluster läuft → **ERLEDIGT** (agent-k8s-local, v1.27.3)
- ✅ podinfo erreichbar unter `http://demo.localhost` → **ERLEDIGT**
- ✅ Browser zeigt podinfo-UI → **BESTÄTIGT**
- ⏸️ Security-Tools funktionieren (Trivy, Gitleaks) → **PHASE 2**

**→ Wir können jetzt lokal entwickeln ohne Cloud!** ✅

| Check | Command | Erwartetes Ergebnis | Status |
|-------|---------|---------------------|--------|
| **Docker läuft** | `docker ps` | Keine Fehler | ✅ v28.5.0 |
| **kind-Cluster aktiv** | `kind get clusters` | `agent-k8s-local` | ✅ Running |
| **kubectl verbunden** | `kubectl get nodes` | 1 Node `Ready` | ✅ v1.27.3 |
| **Ingress läuft** | `kubectl get pods -n ingress-nginx` | 1/1 `Running` | ✅ Running |
| **podinfo deployed** | `kubectl get pods -n tenant-demo` | 2/2 `Running` | ✅ v6.9.2 |
| **Ingress erreichbar** | `curl http://demo.localhost` | HTTP 200 + JSON | ✅ Tested |
| **Browser-Zugriff** | Browser → `http://demo.localhost` | podinfo-UI | ✅ Works |
| **Trivy funktioniert** | `trivy image alpine:latest` | Scan-Report | ⏸️ Phase 2 |
| **Gitleaks funktioniert** | `gitleaks detect --source .` | Keine Secrets gefunden | ⏸️ Phase 2 |

---

## 📊 Phase 1 - Performance Report

**✅ ERFOLGREICH ABGESCHLOSSEN**

```
Gesamt-Runtime: 1m 9.6s (statt 20-30 min)
Tests bestanden: 46/46 (100%)
Setup-Methode:  Vollautomatisch (1 Befehl)
```

**Block-Details:**
```
Block 1-2 (Tools):         7/7 Tests ✅  ~5s  (idempotent, bereits installiert)
Block 3 (Struktur):       10/10 Tests ✅  ~2s  (Ordner + kind-config.yaml)
Block 4 (Manifests):       5/5 Tests ✅  ~5s  (FluxCD Clone + Fallback)
Block 5 (Cluster):         5/5 Tests ✅ ~17s  (kind create + wait)
Block 6 (Ingress):         7/7 Tests ✅ ~20s  (Helm deploy + ready wait)
Block 7 (podinfo):        12/12 Tests ✅  ~8s  (Helm deploy + HTTP test)
─────────────────────────────────────────────────────────────
TOTAL:                    46/46 Tests ✅ 1m 10s
```

**Optimierungen:**
- ✅ Idempotente Tool-Installation (überspringt wenn vorhanden)
- ✅ Retry-Logik für Timing-Probleme (System Pods, HTTP Endpoint)
- ✅ Parallele Operationen wo möglich
- ✅ hostPort statt NodePort für kind-Kompatibilität
- ✅ Automatische Fallback-Manifeste (FluxCD Repo-Änderungen)

**Scripts:**
- Master: `./setup-template/setup-phase1.sh` (orchestriert alle Blocks)
- Block 1-2: `./setup-template/phase1/01-install-tools/` (install.sh + test.sh)
- Block 3: `./setup-template/phase1/02-create-structure/` (create.sh + test.sh)
- Block 4: `./setup-template/phase1/03-clone-templates/` (clone.sh + test.sh)
- Block 5: `./setup-template/phase1/04-create-cluster/` (create.sh + test.sh)
- Block 6: `./setup-template/phase1/05-deploy-ingress/` (deploy.sh + test.sh)
- Block 7: `./setup-template/phase1/06-deploy-podinfo/` (deploy.sh + test.sh)

---

## 🚀 Phase 2: Git-Workflow + AKS (SPÄTER!)

> ⚠️ **Erst starten wenn Phase 1 zu 100% läuft!** → **✅ PHASE 1 ABGESCHLOSSEN**

### **Block 10: GitHub Actions CI/CD** ⏱️ ~45 min → ⏸️ **GEPLANT**

- [ ] **10.1 CI-Workflow erstellen** (`.github/workflows/ci.yml`)
  - Docker Build + Push zu GHCR
  - Trivy Security-Scan (HIGH/CRITICAL = Fail)
  - Gitleaks Secret-Scan
  - kubeconform Manifest-Validierung
  
  **Voraussetzungen:**
  - GitHub Repository (vorhanden: ADASK-B/agent-ready-k8s)
  - Trivy installieren (siehe Block 2.1)
  - Gitleaks installieren (siehe Block 2.2)
  - kubeconform installieren (siehe Block 2.3)

- [ ] **10.2 PR-Test-Workflow** (`.github/workflows/pr-test.yml`)
  - `helm/kind-action` → ephemerer Cluster
  - Helm Install podinfo
  - Smoke-Tests (curl Healthcheck)
  
  **Features:**
  - Automatische Tests bei jedem PR
  - Ephemerer kind-Cluster (keine Cloud-Kosten)
  - Matrix-Tests: mehrere K8s-Versionen

- [ ] **10.3 GitHub Secrets konfigurieren**
  - `GHCR_TOKEN` für Container-Registry
  - `AZURE_CREDENTIALS` (später für AKS)
  
  **Setup:**
  ```bash
  # GitHub Personal Access Token erstellen
  # Settings → Developer settings → Personal access tokens
  # Permissions: write:packages, read:packages
  ```

- [ ] **10.4 pre-commit Hooks einrichten** (lokal)
  - Gitleaks: Secret-Scan vor Commit
  - kubeconform: YAML-Validierung
  - Shell-Syntax-Check (shellcheck)
  
  **Installation:**
  ```bash
  pip3 install pre-commit
  cat > .pre-commit-config.yaml << 'EOF'
  repos:
    - repo: https://github.com/gitleaks/gitleaks
      rev: v8.18.0
      hooks:
        - id: gitleaks
    - repo: https://github.com/yannh/kubeconform
      rev: v0.6.3
      hooks:
        - id: kubeconform
  EOF
  pre-commit install
  ```

---

### **Block 11: Argo CD Installation (GitOps)** ⏱️ ~30 min → ⏸️ **GEPLANT**

- [ ] **11.1 Argo CD lokal installieren**
  ```bash
  # Argo CD in kind-Cluster deployen
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  
  # Warten bis Argo CD bereit ist
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
  
  # Admin Password abrufen
  argocd admin initial-password -n argocd
  
  # Port-Forward für UI
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  ```
  
  **Was passiert:**
  - Deployed Argo CD in kind-Cluster (namespace: argocd)
  - UI verfügbar unter https://localhost:8080
  - Git wird zur Single Source of Truth
  
  **Voraussetzungen:**
  - Argo CD CLI installiert (✅ v2.13+)
  - kind-Cluster läuft (✅ agent-k8s-local)
  - kubectl funktioniert

- [ ] **11.2 Argo CD Applications erstellen**
  - `clusters/local/infrastructure.yaml` (Argo CD App für Infra)
  - `clusters/local/tenants/demo.yaml` (Argo CD App für podinfo)
  - `apps/podinfo/base/` (Standard K8s Manifeste) ✅ vorhanden
  
  **Struktur:**
  ```
  clusters/local/
  ├── argocd-apps/          # Argo CD Application Manifeste
  │   ├── infrastructure.yaml
  │   └── tenants/
  │       └── demo.yaml
  ```
  
  **Beispiel Application:**
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: podinfo-demo
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/ADASK-B/agent-ready-k8s
      targetRevision: main
      path: apps/podinfo/tenants/demo
    destination:
      server: https://kubernetes.default.svc
      namespace: tenant-demo
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  ```

- [ ] **11.3 GitOps-Test**
  ```bash
  # Änderung in Git pushen
  vim apps/podinfo/tenants/demo/deployment.yaml
  # replicas: 2 → 3
  git commit -m "test: scale podinfo to 3 replicas"
  git push
  
  # Argo CD synced automatisch (max. 3 min)
  argocd app list
  argocd app get podinfo-demo --watch
  kubectl get pods -n tenant-demo
  # Erwartung: 3/3 Pods nach 1-2 Minuten
  
  # Oder manuell triggern
  argocd app sync podinfo-demo
  ```
  
  **GitOps-Vorteile:**
  - Git = Single Source of Truth
  - Automatische Deployments (kein kubectl/helm mehr nötig)
  - Audit-Trail (Git History)
  - Rollback via `git revert`
  - UI Dashboard für visuelles Monitoring

- [ ] **11.4 Sealed Secrets integrieren** (für Phase 2 AKS)
  ```bash
  # Controller deployen (siehe Block 6.2)
  kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
  
  # Secret verschlüsseln
  kubectl create secret generic my-secret --from-literal=password=supersecret --dry-run=client -o yaml | \
    kubeseal -o yaml > my-sealed-secret.yaml
  
  # In Git committen (verschlüsselt, sicher!)
  git add my-sealed-secret.yaml
  git commit -m "feat: add sealed secret"
  git push
  ```

---

### **Block 12: AKS-Cluster aufsetzen** ⏱️ ~60 min → ⏸️ **GEPLANT**

- [ ] **12.1 Azure CLI Setup**
  ```bash
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  az login
  az account show
  ```
  
  **Voraussetzungen:**
  - Azure-Account (200€ Free Credit für Neukunden)
  - Subscription mit ausreichend Quota

- [ ] **12.2 AKS-Cluster erstellen** (Free Tier)
  ```bash
  az group create --name agent-k8s-rg --location westeurope
  
  az aks create \
    --resource-group agent-k8s-rg \
    --name agent-k8s-prod \
    --node-count 3 \
    --node-vm-size Standard_B2s \
    --enable-managed-identity \
    --generate-ssh-keys \
    --tier free \
    --network-plugin azure \
    --network-policy azure
  ```
  
  **Cluster-Specs:**
  - 3x Standard_B2s Nodes (2 vCPU, 4GB RAM)
  - Free Tier (nur VM-Kosten, keine Control Plane)
  - Azure CNI + Network Policy
  - Managed Identity (keine Service Principals)
  - Geschätzte Kosten: ~50-70€/Monat
  
  **Performance:**
  - Erstell-Zeit: ~5-10 Minuten
  - Kubernetes Version: Latest stable (automatisch)

- [ ] **12.3 Argo CD in AKS installieren**
  ```bash
  az aks get-credentials --resource-group agent-k8s-rg --name agent-k8s-prod
  
  # Argo CD in AKS deployen
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  
  # Mit GitHub Repository verbinden
  argocd login <ARGOCD_SERVER>
  argocd repo add https://github.com/ADASK-B/agent-ready-k8s
  
  # App of Apps Pattern für Production
  kubectl apply -f clusters/production/argocd-apps/root-app.yaml
  ```
  
  **Was passiert:**
  - Argo CD deployed in AKS (`argocd` Namespace)
  - Monitoring: `clusters/production/` Ordner
  - Auto-Sync bei Git-Push
  
  **Struktur:**
  ```
  clusters/
  ├── local/         # kind-Cluster (Phase 1) ✅
  │   └── argocd-apps/
  └── production/    # AKS-Cluster (Phase 2)
      ├── argocd-apps/
      │   ├── root-app.yaml
      │   └── tenants/
      │       └── demo.yaml
      └── infrastructure/
  ```

- [ ] **12.4 AKS Baseline Automation integrieren** (optional)
  ```bash
  git clone https://github.com/Azure/aks-baseline-automation.git /tmp/aks-baseline
  cd /tmp/aks-baseline
  
  # Bicep-Templates für Production-Grade Setup
  # - Network Policies
  # - Azure Policy
  # - Azure Monitor
  # - Azure Key Vault
  ```
  
  **Features:**
  - Zero-Trust Networking (NSG, Private Endpoints)
  - Pod Security Standards (PSS)
  - Azure Monitor + Log Analytics
  - Backup Strategy (Velero)
  - Disaster Recovery (Multi-Region)

- [ ] **12.5 Ingress-Controller in AKS** (Application Gateway oder nginx)
  
  **Option A: Application Gateway Ingress Controller** (empfohlen für Prod)
  ```bash
  az aks enable-addons \
    --resource-group agent-k8s-rg \
    --name agent-k8s-prod \
    --addons ingress-appgw \
    --appgw-subnet-cidr "10.2.0.0/16"
  ```
  
  **Option B: ingress-nginx** (wie in Phase 1)
  ```bash
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
  ```

- [ ] **12.6 DNS + TLS Setup** (Let's Encrypt)
  ```bash
  # cert-manager installieren
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
  
  # ClusterIssuer erstellen (Let's Encrypt)
  cat > letsencrypt-prod.yaml << 'EOF'
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: your-email@example.com
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
      - http01:
          ingress:
            class: nginx
  EOF
  kubectl apply -f letsencrypt-prod.yaml
  ```
  
  **Ingress mit TLS:**
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: podinfo
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
  spec:
    ingressClassName: nginx
    tls:
    - hosts:
      - demo.yourdomain.com
      secretName: podinfo-tls
    rules:
    - host: demo.yourdomain.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: podinfo
              port:
                number: 9898
  ```

---

### **Block 13: End-to-End-Test** ⏱️ ~20 min → ⏸️ **GEPLANT**

- [ ] **13.1 Lokale Änderung machen**
  ```bash
  # podinfo auf v6.10.0 upgraden (Beispiel)
  vim apps/podinfo/tenants/demo/patch.yaml
  # helmrelease → chart version: 6.10.0
  ```

- [ ] **13.2 Commit + Push**
  ```bash
  git add apps/podinfo/tenants/demo/patch.yaml
  git commit -m "feat: upgrade podinfo to v6.10.0"
  git push origin main
  ```

- [ ] **13.3 Pipeline beobachten**
  ```bash
  # GitHub Actions läuft (CI)
  # - Gitleaks: Secret-Scan ✅
  # - Trivy: Container-Scan ✅
  # - kubeconform: Manifest-Validierung ✅
  # - PR-Tests: Ephemerer kind-Cluster ✅
  
  # Argo CD synced in AKS (3-5 min)
  argocd app list
  argocd app get podinfo-demo --watch
  
  # Neue Version deployed
  kubectl get pods -n tenant-demo -o jsonpath='{.items[0].spec.containers[0].image}'
  # ghcr.io/stefanprodan/podinfo:6.10.0
  ```

- [ ] **13.4 Rollback-Test**
  ```bash
  # Fehler gefunden? Sofort zurück!
  git revert HEAD
  git push origin main
  
  # → Argo CD rollt automatisch zurück (3-5 min)
  # → Alte Version läuft wieder
  
  # Oder sofort via CLI
  argocd app rollback podinfo-demo <REVISION>
  ```
  
  **GitOps-Vorteil:**
  - Rollback = 1 Git-Command (oder CLI)
  - Kein kubectl/helm nötig
  - Audit-Trail in Git-History
  - Automatisch synchronisiert
  - Instant Rollback via Argo CD UI/CLI

- [ ] **13.5 Multi-Environment Test** (Staging → Production)
  ```bash
  # Änderung in Staging testen
  vim apps/podinfo/tenants/staging/deployment.yaml
  git push
  
  # Warten + beobachten (Staging)
  argocd app get podinfo-staging --watch
  
  # Wenn OK: Production deployen
  vim apps/podinfo/tenants/production/deployment.yaml
  git push
  
  # Production Update (mit Sync Waves / Approval in Argo CD)
  argocd app sync podinfo-production
  ```

---

## ✅ Erfolgskriterien Phase 2

**🎯 Phase 2 ist fertig wenn:**
- ✅ GitHub Actions CI/CD läuft (Security-Scans, Tests)
- ✅ Argo CD deployed automatisch zu AKS
- ✅ `git push` → App-Update in Azure (3-5 min)
- ✅ Rollback via `git revert` oder Argo CD CLI funktioniert
- ✅ TLS-Zertifikate automatisch (Let's Encrypt)
- ✅ Monitoring + Alerting aktiv (Azure Monitor)

**Checkliste:**

| Check | Command | Erwartetes Ergebnis | Status |
|-------|---------|---------------------|--------|
| **GitHub Actions läuft** | GitHub → Actions Tab | CI-Pipeline grün | ⏸️ TODO |
| **Argo CD in AKS** | `argocd app list` | Alle synced | ⏸️ TODO |
| **AKS-Cluster läuft** | `az aks show -g agent-k8s-rg -n agent-k8s-prod` | provisioningState: Succeeded | ⏸️ TODO |
| **podinfo in AKS** | `kubectl get pods -n tenant-demo` | 2/2 Running | ⏸️ TODO |
| **Public URL** | `curl https://demo.yourdomain.com` | HTTP 200 + JSON | ⏸️ TODO |
| **TLS funktioniert** | `curl -vI https://demo.yourdomain.com` | Valid cert (Let's Encrypt) | ⏸️ TODO |
| **GitOps-Update** | Git push → `argocd app get podinfo-demo` | Auto-synced | ⏸️ TODO |
| **Rollback** | `git revert` + push | Alte Version läuft | ⏸️ TODO |

---

## 📊 Phase 2 - Geschätzte Kosten

**Azure-Ressourcen (monatlich):**
```
AKS Control Plane (Free Tier):           0,00€
3x Standard_B2s Nodes (2 vCPU, 4GB):    ~60,00€
Azure Load Balancer (Basic):            ~15,00€
Public IP (Static):                      ~3,00€
Azure Monitor (Log Analytics):          ~10,00€
────────────────────────────────────────────
TOTAL (geschätzt):                      ~88,00€/Monat
```

**Optimierungen:**
- ✅ Spot Instances für Dev/Staging (-70%)
- ✅ Auto-Scaling (Scale-to-Zero nachts)
- ✅ Reserved Instances (1 Jahr: -30%)
- ✅ Free Tier Services nutzen (Azure Monitor, Key Vault)

**Vergleich:**
- Phase 1 (lokal): **0€** ✅ AKTIV
- Phase 2 (AKS): **~88€/Monat** (optional)
- Alternative: DigitalOcean Kubernetes **~36€/Monat** (günstiger)

---

## 📊 Phase 2 - Erweiterte Features (Optional)

### **Monitoring & Observability**
- [ ] Prometheus + Grafana in AKS
- [ ] Azure Monitor Integration
- [ ] Log Analytics Workspace

### **Security Hardening**
- [ ] Azure Key Vault + External Secrets Operator
- [ ] Pod Security Standards (restricted)
- [ ] Network Policies (Zero Trust)
- [ ] OPA Gatekeeper Policies

### **Multi-Tenancy**
- [ ] Namespace-Templates
- [ ] ResourceQuotas pro Tenant
- [ ] Hierarchical Namespaces (HNC)

### **Disaster Recovery**
- [ ] Velero (Cluster-Backups)
- [ ] Geo-Redundanz (Multi-Region)
- [ ] Database-Backups (automatisch)

---

## 🚀 Nächste Schritte (Nach Phase 1)

## 🚀 Nächste Schritte (Nach Phase 1)

**Wenn Phase 1 läuft (podinfo lokal funktioniert):**

1. ✅ **Erstmal lokal entwickeln!**
   - Eigene Apps deployen
   - Template für eigene Projekte anpassen
   - Mit kind + Helm experimentieren

2. ⏸️ **Pause machen, Template nutzen**
   - Mehrere Tenants lokal testen
   - Verschiedene Apps ausprobieren
   - Team-Mitglieder onboarden

3. 🚀 **Dann Phase 2 starten** (wenn bereit für Cloud)
   - GitHub Actions CI/CD
   - Flux Bootstrap
   - AKS-Deployment
   - Git Push = Auto-Deploy

---

## 📝 Notizen & Probleme

**Problem-Log:**
```
[04.10.2025] [Timing-Issue] System Pods nicht sofort Ready → Fix: Retry-Logik (3×2s)
[04.10.2025] [Timing-Issue] HTTP 503 nach podinfo Deploy → Fix: Retry-Logik (5×3s)
[04.10.2025] [kind-Port-Mapping] NodePort 80/443 invalid → Fix: hostPort.enabled=true
[04.10.2025] [FluxCD-Repo] Staging-Manifeste fehlen → Fix: Fallback-Erstellung
```

**Performance-Tracking Phase 1:**
```
Block 1-2 (Tools):         ~5s   ✅
Block 3 (Struktur):        ~2s   ✅
Block 4 (Manifeste):       ~5s   ✅
Block 5 (Cluster):        ~17s   ✅
Block 6 (Ingress):        ~20s   ✅
Block 7 (podinfo):         ~8s   ✅
Block 8 (Tests):       integriert ✅
Block 9 (Docs):         🚧 TODO
───────────────────────────────────
TOTAL:              1m 10s  ✅
```

**Lessons Learned:**
1. ✅ Retry-Logik ist essentiell für Kubernetes (Pods starten asynchron)
2. ✅ kind benötigt hostPort statt NodePort für Ports <1024
3. ✅ FluxCD-Beispiel-Repos ändern sich → Fallback-Logik nötig
4. ✅ Idempotente Scripts = schnellere Reruns
5. ✅ Modulare Struktur (phase1/) = besseres Debugging
6. ✅ Unabhängige Test-Scripts = klare Fehler-Identifikation

---

## 🔗 Template-Quellen

| Komponente | Quelle | Lizenz | Phase |
|------------|--------|--------|-------|
| **Argo CD** | https://github.com/argoproj/argo-cd | Apache 2.0 | 1 + 2 |
| **AKS Baseline** | https://github.com/Azure/aks-baseline-automation | MIT | 2 |
| **podinfo (Demo)** | https://github.com/stefanprodan/podinfo | Apache 2.0 | 1 |
| **helm/kind-action** | https://github.com/helm/kind-action | Apache 2.0 | 2 |

---

## 🎯 Milestone-Übersicht

### **✅ Phase 1: Lokale Template** → **ABGESCHLOSSEN**
**Ziel:** `http://demo.localhost` läuft  
**Dauer:** 1m 10s (statt geplant 2-3h!)  
**Blocker:** Keine  
**Status:** ✅ PRODUKTIV

**Achievements:**
- ✅ Vollautomatische Installation (1 Command)
- ✅ 46/46 Tests bestanden (100%)
- ✅ Runtime-Optimierung: 99% schneller als geschätzt
- ✅ Modulare Struktur (6 Blocks, jeweils testbar)
- ✅ podinfo v6.9.2 läuft unter http://demo.localhost
- ✅ kind-Cluster v1.27.3 stabil
- ✅ Retry-Logik für Timing-Probleme
- ✅ Idempotente Scripts (mehrfach ausführbar)

### **⏸️ Phase 2: Git-Workflow + AKS** → **GEPLANT**
**Ziel:** `git push` → Auto-Deploy zu Azure  
**Dauer:** ~3-4h (geschätzt)  
**Kosten:** ~88€/Monat (Azure AKS)  
**Blocker:** 
- ✅ Phase 1 muss 100% funktionieren → **ERFÜLLT**
- ⏸️ Azure-Account benötigt (200€ Free Credit verfügbar)
- ⏸️ GitHub-Repo Actions aktiviert (bereits public)
- ⏸️ DNS-Domain für TLS (optional: Azure DNS ~1€/Monat)

**Geplante Features:**
- GitHub Actions CI/CD (Security-Scans, Tests)
- Argo CD GitOps (Auto-Sync bei Git-Push)
- AKS-Cluster (3 Nodes, Free Tier Control Plane)
- Let's Encrypt TLS (automatisch)
- Azure Monitor + Alerting
- Sealed Secrets (sichere Secret-Verwaltung)
- Multi-Environment (Staging → Production)
- Argo CD UI Dashboard (visuelles Monitoring)

---

**🎯 Phase 1 Ziel:** Vollautomatisches Setup mit `./setup-template/setup-phase1.sh` → ✅ **ERREICHT**

**🌐 Demo:** http://demo.localhost → ✅ **LÄUFT**

**📌 Focus JETZT:** 
1. ✅ Phase 1 abgeschlossen (1m 10s, 46/46 Tests)
2. 🚧 Dokumentation vervollständigen (README.md, SETUP.md)
3. ⏸️ Phase 2 vorbereiten (GitHub Actions, Flux, AKS)

**🚀 Next Steps:**
- Lokal entwickeln und testen mit der fertigen Template
- Eigene Apps auf Basis von podinfo-Beispiel deployen
- Multi-Tenancy testen (weitere Namespaces)
- Bei Bedarf: Phase 2 für Cloud-Deployment starten
