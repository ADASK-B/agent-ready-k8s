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
Flux in AKS zieht Update
    ↓
✅ App läuft in Azure Cloud
```

**→ Kommt erst wenn Phase 1 100% funktioniert!**

---

## 📋 Checkliste: Phase 1 (Lokale Template)

> **🚀 Quick Start:** Komplette Automation mit `./setup-template/setup-complete-template.sh`  
> **⏱️ Runtime:** ~20-30 Minuten (Block 3-8 automatisch)  
> **Ergebnis:** Running demo at `http://demo.localhost`

### **Block 1: Tool-Installation (Ubuntu)** ⏱️ ~30 min

- [ ] **1.1 Docker Engine CE installieren**
  ```bash
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  ```
  - **Test:** `docker run hello-world`
  - ⚠️ **Reboot erforderlich!** → `sudo reboot`

- [ ] **1.2 kind installieren** (Kubernetes in Docker)
  ```bash
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  ```
  - **Test:** `kind version`

- [ ] **1.3 kubectl installieren**
  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  ```
  - **Test:** `kubectl version --client`

- [ ] **1.4 Flux CLI installieren**
  ```bash
  curl -s https://fluxcd.io/install.sh | sudo bash
  ```
  - **Test:** `flux version`

- [ ] **1.5 Helm installieren**
  ```bash
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```
  - **Test:** `helm version`

- [ ] **1.6 Task installieren** (Makefile-Alternative)
  ```bash
  sudo snap install task --classic
  ```
  - **Test:** `task --version`

---

### **Block 2: Security Tools installieren** ⏱️ ~15 min

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

### **Block 3: Projekt-Struktur erstellen** ⏱️ ~20 min

- [ ] **3.1 Basis-Ordnerstruktur anlegen**
  ```bash
  mkdir -p apps/podinfo/{base,tenants/demo}
  mkdir -p clusters/{local,production}/{flux-system,tenants}
  mkdir -p infrastructure/{sources,controllers/{ingress-nginx,sealed-secrets}}
  mkdir -p policies/{namespace-template,conftest}
  mkdir -p setup-template/utils
  mkdir -p docs
  ```

- [ ] **3.2 kind-config.yaml erstellen** (im Root)
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

- [ ] **3.3 .gitignore erstellen**
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

- [ ] **3.4 Taskfile.yml erstellen** (Agent-Commands)
  - Siehe separates Template unten ⬇️

---

### **Block 4: Template-Struktur von Best-Practice-Repos übernehmen** ⏱️ ~25 min

> **Ziel:** Flux Example + podinfo + Lizenzen korrekt integrieren

**📦 Was holen wir woher?**

| Quelle | Datei/Ordner im Original | Ziel in unserem Projekt | Zweck |
|--------|--------------------------|-------------------------|-------|
| **Flux Example** | `apps/base/podinfo/` | `apps/podinfo/base/` | HelmRelease + Kustomization für podinfo |
| **Flux Example** | `apps/staging/podinfo/` | `apps/podinfo/tenants/demo/` | Tenant-spezifische Overlays |
| **Flux Example** | `clusters/staging/` | `clusters/local/` | Flux-Kustomization für lokalen Cluster |
| **Flux Example** | `infrastructure/` | `infrastructure/` | Ingress-Nginx, Sealed Secrets HelmReleases |
| **podinfo Helm Chart** | (via `helm repo add`) | Deployed in `tenant-demo` Namespace | Demo-Webserver für Tests |

**✅ Nach Block 4:** Alle GitOps-Manifeste (HelmRelease, Kustomization) liegen bereit, LICENSE-3RD-PARTY.md existiert

---

#### **Option A: Automatisches Setup (empfohlen)** ⏱️ ~5 min

- [ ] **4.1 Setup-Skript ausführen**
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  chmod +x setup-template/02-setup-template-structure.sh
  ./setup-template/02-setup-template-structure.sh
  ```
  
  **Das Skript macht automatisch:**
  - Clont Flux Example-Repo
  - Kopiert relevante Dateien (podinfo, Kustomize-Struktur)
  - Passt Pfade an (staging → local)
  - Erstellt LICENSE-3RD-PARTY.md
  - Räumt Temp-Dateien auf

- [ ] **4.2 Ergebnis prüfen**
  ```bash
  tree -L 3 apps/podinfo
  cat LICENSE-3RD-PARTY.md
  ```

---

#### **Option B: Manuelle Setup (wenn Skript fehlschlägt)** ⏱️ ~25 min

- [ ] **4.3 Flux Example-Repo clonen**
  ```bash
  cd /tmp
  git clone --depth 1 https://github.com/fluxcd/flux2-kustomize-helm-example.git flux-example
  cd flux-example
  tree -L 3  # Struktur ansehen
  ```

- [ ] **4.4 podinfo-Struktur übernehmen**
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  
  # Base-Manifeste kopieren (wenn im Flux-Repo vorhanden)
  if [ -d "/tmp/flux-example/apps/base/podinfo" ]; then
    cp -r /tmp/flux-example/apps/base/podinfo/* apps/podinfo/base/
  fi
  
  # Alternativ: Eigene Manifeste erstellen (siehe unten)
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

  ## FluxCD flux2-kustomize-helm-example
  - **Source:** https://github.com/fluxcd/flux2-kustomize-helm-example
  - **License:** Apache-2.0
  - **Copyright:** Cloud Native Computing Foundation (CNCF)
  - **Usage:** Repository structure, GitOps patterns, Kustomize layouts

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
  This project (agent-ready-k8s-stack) is licensed under MIT (see LICENSE).
  EOF
  ```

- [ ] **4.7 Git-History bereinigen**
  ```bash
  # Temp-Repos löschen (keine .git-History übernehmen!)
  rm -rf /tmp/flux-example
  rm -rf /tmp/aks-baseline-automation
  ```

- [ ] **4.8 README Credits hinzufügen**
  ```bash
  # Am Ende von README.md ergänzen:
  cat >> README.md << 'EOF'

  ## 🙏 Credits & Attributions

  This template is built upon best practices from:
  - [FluxCD flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example) (Apache-2.0)
  - [podinfo](https://github.com/stefanprodan/podinfo) by Stefan Prodan (Apache-2.0)
  - [AKS Baseline](https://github.com/Azure/aks-baseline-automation) by Microsoft (MIT)

  See [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) for full attribution.
  EOF
  ```

---

#### **Fallback: podinfo manuell erstellen (wenn Flux-Repo kein podinfo hat)** ⏱️ ~10 min

- [ ] **4.9 podinfo HelmRelease erstellen**
  ```bash
  cat > apps/podinfo/base/helmrelease.yaml << 'EOF'
  apiVersion: helm.toolkit.fluxcd.io/v2beta1
  kind: HelmRelease
  metadata:
    name: podinfo
    namespace: flux-system
  spec:
    interval: 5m
    chart:
      spec:
        chart: podinfo
        version: '>=6.5.0'
        sourceRef:
          kind: HelmRepository
          name: podinfo
          namespace: flux-system
    values:
      replicaCount: 2
      ingress:
        enabled: true
        className: nginx
        hosts:
          - host: demo.localhost
            paths:
              - path: /
                pathType: Prefix
  EOF
  ```

- [ ] **4.10 Kustomization erstellen**
  ```bash
  cat > apps/podinfo/base/kustomization.yaml << 'EOF'
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
  EOF
  ```

---

### **Block 5: Lokalen kind-Cluster erstellen** ⏱️ ~10 min

- [ ] **5.1 kind-Cluster starten**
  ```bash
  cd /home/arthur/Dev/agent-ready-k8s
  kind create cluster --name agent-k8s-local --config=kind-config.yaml
  ```
  - **Test:** `kubectl cluster-info`

- [ ] **5.2 Cluster-Context setzen**
  ```bash
  kubectl config use-context kind-agent-k8s-local
  kubectl get nodes
  ```

- [ ] **5.3 /etc/hosts eintragen** (für Ingress)
  ```bash
  echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts
  ```

---

### **Block 6: Infrastructure deployen** ⏱️ ~15 min

- [ ] **6.1 Ingress-Nginx installieren**
  ```bash
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.hostPort.enabled=true \
    --set controller.service.type=NodePort
  ```
  - **Test:** `kubectl get pods -n ingress-nginx`

- [ ] **6.2 Sealed Secrets Controller installieren**
  ```bash
  kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
  tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
  sudo mv kubeseal /usr/local/bin/
  rm kubeseal-0.24.0-linux-amd64.tar.gz
  ```
  - **Test:** `kubectl get pods -n kube-system | grep sealed-secrets`

- [ ] **6.3 Warten bis alles läuft**
  ```bash
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
  ```

---

### **Block 7: Demo-App (podinfo) deployen** ⏱️ ~20 min

- [ ] **7.1 Namespace erstellen**
  ```bash
  kubectl create namespace tenant-demo
  ```

- [ ] **7.2 podinfo via Helm deployen**
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

- [ ] **7.3 Deployment-Status prüfen**
  ```bash
  kubectl get pods -n tenant-demo
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=podinfo -n tenant-demo --timeout=300s
  ```

- [ ] **7.4 Ingress testen**
  ```bash
  kubectl get ingress -n tenant-demo
  curl http://demo.localhost
  ```

---

### **Block 8: Finaler Funktionstest** ⏱️ ~10 min

- [ ] **8.1 Browser-Test**
  - Browser öffnen: `http://demo.localhost`
  - ✅ Sollte podinfo-UI zeigen (Version, Hostname, etc.)

- [ ] **8.2 API-Test**
  ```bash
  curl http://demo.localhost/healthz
  # Erwartung: {"status":"ok"}
  ```

- [ ] **8.3 Logs prüfen**
  ```bash
  kubectl logs -l app.kubernetes.io/name=podinfo -n tenant-demo --tail=50
  ```

- [ ] **8.4 Security-Scan (Beispiel)**
  ```bash
  trivy image stefanprodan/podinfo:latest --severity HIGH,CRITICAL
  ```

---

### **Block 9: Dokumentation vervollständigen** ⏱️ ~15 min

- [ ] **9.1 README.md anpassen**
  - Quick Start aktualisieren (mit podinfo-Beispiel)
  - Screenshots hinzufügen (optional)

- [ ] **9.2 SETUP.md erstellen** (in `docs/`)
  - Detaillierte Tool-Installationsanleitung
  - Troubleshooting-Tipps

- [ ] **9.3 Taskfile.yml testen**
  ```bash
  task cluster:info
  task tenant:logs TENANT=demo
  ```

---

## ✅ Erfolgskriterien Phase 1 (Abnahmetest)

**🎯 Phase 1 ist fertig wenn:**
- ✅ Alle Tools installiert (Docker, kind, kubectl, Helm, Trivy, ...)
- ✅ kind-Cluster läuft
- ✅ podinfo erreichbar unter `http://demo.localhost`
- ✅ Browser zeigt podinfo-UI
- ✅ Security-Tools funktionieren (Trivy, Gitleaks)

**→ Dann können wir lokal entwickeln ohne Cloud!**

| Check | Command | Erwartetes Ergebnis |
|-------|---------|---------------------|
| **Docker läuft** | `docker ps` | Keine Fehler |
| **kind-Cluster aktiv** | `kind get clusters` | `agent-k8s-local` |
| **kubectl verbunden** | `kubectl get nodes` | 1 Node `Ready` |
| **Ingress läuft** | `kubectl get pods -n ingress-nginx` | 1/1 `Running` |
| **podinfo deployed** | `kubectl get pods -n tenant-demo` | 2/2 `Running` |
| **Ingress erreichbar** | `curl http://demo.localhost` | HTTP 200 + JSON |
| **Browser-Zugriff** | Browser → `http://demo.localhost` | podinfo-UI |
| **Trivy funktioniert** | `trivy image alpine:latest` | Scan-Report |
| **Gitleaks funktioniert** | `gitleaks detect --source .` | Keine Secrets gefunden |

---

## 🚀 Phase 2: Git-Workflow + AKS (SPÄTER!)

> ⚠️ **Erst starten wenn Phase 1 zu 100% läuft!**

### **Block 10: GitHub Actions CI/CD** ⏱️ ~45 min

- [ ] **10.1 CI-Workflow erstellen** (`.github/workflows/ci.yml`)
  - Docker Build + Push zu GHCR
  - Trivy Security-Scan (HIGH/CRITICAL = Fail)
  - Gitleaks Secret-Scan
  - kubeconform Manifest-Validierung

- [ ] **10.2 PR-Test-Workflow** (`.github/workflows/pr-test.yml`)
  - `helm/kind-action` → ephemerer Cluster
  - Helm Install podinfo
  - Smoke-Tests (curl Healthcheck)

- [ ] **10.3 GitHub Secrets konfigurieren**
  - `GHCR_TOKEN` für Container-Registry
  - `AZURE_CREDENTIALS` (später für AKS)

---

### **Block 11: Flux Bootstrap (GitOps)** ⏱️ ~30 min

- [ ] **11.1 Flux lokal testen**
  ```bash
  flux bootstrap github \
    --owner=ADASK-B \
    --repository=agent-ready-k8s \
    --branch=main \
    --path=clusters/local \
    --personal
  ```

- [ ] **11.2 Flux-Manifeste erstellen**
  - `clusters/local/infrastructure.yaml` (GitRepository für Infra)
  - `clusters/local/tenants/demo.yaml` (Kustomization für podinfo)
  - `apps/podinfo/base/kustomization.yaml` (Kustomize-Basis)

- [ ] **11.3 GitOps-Test**
  ```bash
  # Änderung in Git pushen
  git commit -m "test: update podinfo replicas"
  git push
  # → Flux reconciled automatisch (max. 5 min)
  ```

---

### **Block 12: AKS-Cluster aufsetzen** ⏱️ ~60 min

- [ ] **12.1 Azure CLI Setup**
  ```bash
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  az login
  ```

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
    --tier free
  ```

- [ ] **12.3 Flux in AKS bootstrappen**
  ```bash
  az aks get-credentials --resource-group agent-k8s-rg --name agent-k8s-prod
  flux bootstrap github \
    --owner=ADASK-B \
    --repository=agent-ready-k8s \
    --branch=main \
    --path=clusters/production \
    --personal
  ```

- [ ] **12.4 AKS Baseline Automation integrieren** (optional)
  - Bicep-Templates für Production-Grade Setup
  - Network Policies, Azure Policy, etc.

---

### **Block 13: End-to-End-Test** ⏱️ ~20 min

- [ ] **13.1 Lokale Änderung machen**
  ```bash
  # podinfo auf v6.5.0 upgraden
  vim apps/podinfo/base/kustomization.yaml
  ```

- [ ] **13.2 Commit + Push**
  ```bash
  git add .
  git commit -m "feat: upgrade podinfo to v6.5.0"
  git push origin main
  ```

- [ ] **13.3 Pipeline beobachten**
  - GitHub Actions läuft (CI)
  - Flux reconciled in AKS (5-10 min)
  - `kubectl get pods -n tenant-demo` → neue Version

- [ ] **13.4 Rollback-Test**
  ```bash
  git revert HEAD
  git push origin main
  # → Flux rollt automatisch zurück
  ```

---

## ✅ Erfolgskriterien Phase 2

**🎯 Phase 2 ist fertig wenn:**
- ✅ GitHub Actions CI/CD läuft
- ✅ Flux deployed automatisch zu AKS
- ✅ `git push` → App-Update in Azure (5-10 min)
- ✅ Rollback via `git revert` funktioniert

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
[Datum] [Problem] [Lösung]
```

**Performance-Tracking Phase 1:**
```
Block 1: ___ min
Block 2: ___ min
Block 3: ___ min
Block 4: ___ min
Block 5: ___ min
Block 6: ___ min
Block 7: ___ min
Block 8: ___ min
Block 9: ___ min
───────────────────
TOTAL:   ___ min
```

---

## 🔗 Template-Quellen

| Komponente | Quelle | Lizenz | Phase |
|------------|--------|--------|-------|
| **Flux Example** | https://github.com/fluxcd/flux2-kustomize-helm-example | Apache 2.0 | 1 + 2 |
| **AKS Baseline** | https://github.com/Azure/aks-baseline-automation | MIT | 2 |
| **podinfo (Demo)** | https://github.com/stefanprodan/podinfo | Apache 2.0 | 1 |
| **helm/kind-action** | https://github.com/helm/kind-action | Apache 2.0 | 2 |

---

## 🎯 Milestone-Übersicht

### **✅ Phase 1: Lokale Template** (JETZT)
**Ziel:** `http://demo.localhost` läuft  
**Dauer:** ~2-3h  
**Blocker:** Keine (alles lokal, kostenlos)

### **⏸️ Phase 2: Git-Workflow + AKS** (SPÄTER)
**Ziel:** `git push` → Auto-Deploy zu Azure  
**Dauer:** ~3-4h  
**Blocker:** 
- Phase 1 muss 100% funktionieren
- Azure-Account benötigt (200€ Free Credit)
- GitHub-Repo muss public oder Actions aktiviert sein

---

**🎯 Phase 1 Ziel:** Du kannst `task cluster:create && task tenant:create TENANT=demo` ausführen und die App läuft unter `http://demo.localhost` ✅

**📌 Focus JETZT:** Nur Block 1-9 abarbeiten, dann lokal entwickeln können!
