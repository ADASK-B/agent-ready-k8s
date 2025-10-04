# agent-ready-k8s-stack

> **Production-Ready Kubernetes Stack für Agent-gesteuerte Entwicklung**  
> Lokale Multi-Tenant-SaaS-Entwicklung mit GitOps, Security-First & automatischem Cloud-Deployment

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Flux](https://img.shields.io/badge/Flux-2.2+-purple.svg)](https://fluxcd.io/)

---

## 📖 Inhaltsverzeichnis

- [🎯 Zielbild & Workflow](#-zielbild--workflow)
- [🏗️ Architektur-Überblick](#️-architektur-überblick)
- [🛠️ Techstack (Detailliert)](#️-techstack-detailliert)
- [🏢 Multi-Tenancy-Strategie](#-multi-tenancy-strategie)
- [🎯 Demo-Anwendung](#-demo-anwendung-chatops-saas)
- [🔐 Secrets-Management](#-secrets-management)
- [📦 Projekt-Struktur](#-projekt-struktur)
- [⚡ Quick Start](#-quick-start)
- [🚀 Lokaler Entwicklungs-Workflow](#-lokaler-entwicklungs-workflow)
- [🌐 Cloud-Deployment (AKS)](#-cloud-deployment-aks)
- [🤝 Agent-Commands](#-agent-commands)
- [🔍 Troubleshooting](#-troubleshooting)
- [💰 Kosten-Kalkulation](#-kosten-kalkulation)
- [📚 Weiterführende Schritte](#-weiterführende-schritte)

---

## 🎯 Zielbild & Workflow

### **Was ist dieses Projekt?**

Ein **vollständiger Kubernetes-Stack** für die Entwicklung von Multi-Tenant-SaaS-Anwendungen, der:
- ✅ **Lokal auf Ubuntu** läuft (kind-Cluster)
- ✅ **Security-First** ist (Trivy, Gitleaks, OPA vor jedem Commit)
- ✅ **GitOps-Native** arbeitet (Flux reconciled automatisch)
- ✅ **Agent-steuerbar** ist (alle Workflows via CLI/Task)
- ✅ **Cloud-ready** ist (Git Push → automatisches AKS-Deployment)
- ✅ **100% Open Source** ist (keine Vendor-Lock-ins)

---

### **Lokaler Entwicklungs-Workflow (Agent-gesteuert)**

```
┌────────────────────────────────────────────────────────────────────┐
│ PHASE 1: LOKALE ENTWICKLUNG (kind-Cluster auf Ubuntu)             │
│────────────────────────────────────────────────────────────────────│
│                                                                     │
│  1. Code ändern (z.B. Chat-UI verbessern)                          │
│     └─→ apps/chat-saas/app/page.tsx                                │
│                                                                     │
│  2. Container bauen & in lokale Registry pushen                    │
│     └─→ task dev:build                                             │
│                                                                     │
│  3. Security-Scans (automatisch vor Commit)                        │
│     ├─→ Trivy: Container-Scan (CVEs)                               │
│     ├─→ Gitleaks: Secret-Scanner                                   │
│     ├─→ kubeconform: K8s-Manifest-Validierung                      │
│     └─→ Syft: SBOM-Generierung                                     │
│                                                                     │
│  4. Ephemerer K8s-Cluster (kind)                                   │
│     ├─→ task cluster:create                                        │
│     ├─→ Flux Bootstrap                                             │
│     └─→ Infrastructure-Deploy (Ingress, Monitoring)                │
│                                                                     │
│  5. Tenant deployen & testen                                       │
│     ├─→ task tenant:create TENANT=demo                             │
│     ├─→ Flux reconciled GitOps-Manifeste                           │
│     ├─→ http://demo.localhost → Chat läuft!                        │
│     └─→ Smoke-Tests (kubectl wait, curl-Tests)                    │
│                                                                     │
│  6. Monitoring & Debugging                                         │
│     ├─→ task tenant:logs TENANT=demo                               │
│     ├─→ task monitoring:open → Grafana                             │
│     └─→ kubectl describe pod (bei Fehlern)                         │
│                                                                     │
│  7. Cleanup                                                        │
│     └─→ task cluster:delete                                        │
│                                                                     │
│────────────────────────────────────────────────────────────────────│
│ PHASE 2: COMMIT & PUSH                                             │
│────────────────────────────────────────────────────────────────────│
│                                                                     │
│  8. Git Commit (Pre-Commit-Hooks laufen automatisch)              │
│     ├─→ git add apps/chat-saas/                                    │
│     ├─→ git commit -m "feat: improved chat UI"                    │
│     └─→ Pre-Commit: Trivy, Gitleaks, kubeconform ✅                │
│                                                                     │
│  9. Git Push                                                       │
│     └─→ git push origin main                                       │
│                                                                     │
│────────────────────────────────────────────────────────────────────│
│ PHASE 3: AUTOMATISCHES CLOUD-DEPLOYMENT                            │
│────────────────────────────────────────────────────────────────────│
│                                                                     │
│  10. GitHub/GitLab triggert CI-Pipeline                            │
│      ├─→ Docker Build & Push zu GHCR                               │
│      ├─→ Trivy Scan (nochmal in CI)                                │
│      └─→ kubectl apply --dry-run (Syntax-Check)                   │
│                                                                     │
│  11. Flux im AKS-Cluster bemerkt neuen Commit                      │
│      ├─→ Flux pollt Git-Repo (alle 5 Minuten)                     │
│      ├─→ Flux Source Controller: "Neuer Commit!"                  │
│      └─→ Flux Kustomize Controller reconciled                      │
│                                                                     │
│  12. Production-Deploy                                             │
│      ├─→ kubectl apply -k apps/chat-saas/tenants/acme/            │
│      ├─→ kubectl apply -k apps/chat-saas/tenants/beta/            │
│      └─→ https://acme.chat-saas.com ist LIVE! 🎉                  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

### **Philosophie & Design-Prinzipien**

| Prinzip | Bedeutung | Vorteil |
|---------|-----------|---------|
| **Shift-Left Security** | Alle Checks VOR dem Commit | Bugs/CVEs früh finden = billiger |
| **GitOps-Native** | Git = Single Source of Truth | Rollback = `git revert`, kein `kubectl` nötig |
| **Ephemere Cluster** | Jeder Test in frischem K8s | Keine Drift zwischen Entwicklern |
| **Agent-Ready** | Alle Tools CLI-steuerbar | KI-Agenten können vollständig automatisieren |
| **Multi-Tenancy** | Namespace-Isolation + DB-RLS | 1 Cluster für viele Kunden (kosteneffizient) |
| **Cloud-Agnostic** | K8s-Standard, kein Vendor-Lock | Von AKS zu GKE/EKS migrierbar |
| **Kostenlos** | 100% Open Source lokal | Nur Cloud-Ressourcen kosten Geld |

---

## 🏗️ Architektur-Überblick

### **3-Ebenen-Architektur**

```
┌──────────────────────────────────────────────────────────────────────┐
│ EBENE 1: INFRASTRUCTURE (Shared Services)                           │
│──────────────────────────────────────────────────────────────────────│
│                                                                       │
│  ┌────────────────┐  ┌────────────────┐  ┌─────────────────────┐   │
│  │ Ingress-Nginx  │  │ Sealed Secrets │  │ Prometheus/Grafana  │   │
│  │ (LoadBalancer) │  │ (Encryption)   │  │ (Monitoring)        │   │
│  └────────────────┘  └────────────────┘  └─────────────────────┘   │
│                                                                       │
│  ┌────────────────┐  ┌────────────────┐                             │
│  │ Cert-Manager   │  │ Flux System    │                             │
│  │ (TLS/Let'sEnc.)│  │ (GitOps)       │                             │
│  └────────────────┘  └────────────────┘                             │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│ EBENE 2: TENANT-ISOLATION (Namespace pro Firma)                     │
│──────────────────────────────────────────────────────────────────────│
│                                                                       │
│  ┌──────────────────────────┐  ┌──────────────────────────┐         │
│  │ Namespace: tenant-acme   │  │ Namespace: tenant-beta   │         │
│  │ (Firma: Acme GmbH)       │  │ (Firma: Beta AG)         │         │
│  │                          │  │                          │         │
│  │  ┌──────────────────┐    │  │  ┌──────────────────┐    │         │
│  │  │ Chat-UI (Next.js)│    │  │  │ Chat-UI (Next.js)│    │         │
│  │  │ Port: 3000       │    │  │  │ Port: 3000       │    │         │
│  │  │ Replicas: 2      │    │  │  │ Replicas: 2      │    │         │
│  │  └──────────────────┘    │  │  └──────────────────┘    │         │
│  │           │              │  │           │              │         │
│  │           ▼              │  │           ▼              │         │
│  │  ┌──────────────────┐    │  │  ┌──────────────────┐    │         │
│  │  │ PostgreSQL       │    │  │  │ PostgreSQL       │    │         │
│  │  │ StatefulSet      │    │  │  │ StatefulSet      │    │         │
│  │  │ PVC: 10Gi        │    │  │  │ PVC: 10Gi        │    │         │
│  │  └──────────────────┘    │  │  └──────────────────┘    │         │
│  │                          │  │                          │         │
│  │  NetworkPolicy: Deny All │  │  NetworkPolicy: Deny All │         │
│  │  ResourceQuota: 4 vCPU   │  │  ResourceQuota: 4 vCPU   │         │
│  └──────────────────────────┘  └──────────────────────────┘         │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│ EBENE 3: DEPARTMENT-ISOLATION (PostgreSQL Row-Level Security)       │
│──────────────────────────────────────────────────────────────────────│
│                                                                       │
│  PostgreSQL DB (tenant-acme):                                        │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Database: acme_hr      (HR-Abteilung)                       │    │
│  │ ├─ users               WHERE department_id='hr-uuid'        │    │
│  │ ├─ chats               WHERE department_id='hr-uuid'        │    │
│  │ └─ messages            WHERE department_id='hr-uuid'        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Database: acme_it      (IT-Abteilung)                       │    │
│  │ ├─ users               WHERE department_id='it-uuid'        │    │
│  │ ├─ chats               WHERE department_id='it-uuid'        │    │
│  │ └─ messages            WHERE department_id='it-uuid'        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  PostgreSQL Row-Level Security Policy:                               │
│  CREATE POLICY dept_isolation ON chats                               │
│    USING (department_id = current_setting('app.department_id'));     │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Techstack (Detailliert)

### **Warum diese Tools? (Begründung für jeden Stack-Teil)**

| Tool | Version | Warum gewählt? | Alternative | Agent-steuerbar? |
|------|---------|----------------|-------------|------------------|
| **Docker Engine CE** | ≥24.0 | Standard-Container-Runtime, große Community | Podman (rootless) | ✅ Ja |
| **kind** | ≥0.20 | Upstream-K8s, 100% Parität zu AKS | k3d (schneller, aber k3s) | ✅ Ja |
| **kubectl** | ≥1.28 | Standard-K8s-CLI | k9s (UI, nicht agent-friendly) | ✅ Ja |
| **Flux CLI** | ≥2.2 | GitOps-Standard, CNCF-Projekt | ArgoCD (UI-fokussiert) | ✅ Ja |
| **Helm** | ≥3.13 | Paket-Manager für K8s | Kustomize (simpler, aber weniger Features) | ✅ Ja |
| **Trivy** | ≥0.48 | Schnellster CVE-Scanner, 0 false-positives | Clair (langsamer) | ✅ Ja |
| **Gitleaks** | ≥8.18 | Bester Secret-Scanner | truffleHog (langsamer) | ✅ Ja |
| **kubeconform** | ≥0.6 | Schnelle K8s-Validierung | kubeval (deprecated) | ✅ Ja |
| **Task** | ≥3.31 | YAML-basiert, einfacher als Make | Makefile (komplexe Syntax) | ✅ Ja |

---

### **Core Tools (Pflicht für lokale Entwicklung)**

#### **1. Docker Engine CE** (Container-Runtime)

```bash
# Installation (Ubuntu)
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# User zu docker-Gruppe hinzufügen (kein sudo nötig)
sudo usermod -aG docker $USER
newgrp docker

# Testen
docker run hello-world
```

**Agent-Nutzung:**
```bash
docker build -t chat-saas:latest .
docker push ghcr.io/ADASK-B/chat-saas:v1.0.0
```

---

#### **2. kind** (Kubernetes in Docker)

```bash
# Installation
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Cluster erstellen
kind create cluster --name agent-k8s-local --config=kind-config.yaml

# kind-config.yaml (für Ingress):
cat <<EOF > kind-config.yaml
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
EOF
```

**Warum kind statt k3d?**
- ✅ **Upstream-Kubernetes** (100% AKS-Parität)
- ✅ **CNCF-Projekt** (aktive Maintenance)
- ✅ **Multi-Node-Support** (für HA-Tests)
- ⚠️ Langsamer als k3d (aber realistischer)

**Agent-Nutzung:**
```bash
kind create cluster --name test-cluster
kubectl --context kind-test-cluster apply -f manifest.yaml
kind delete cluster --name test-cluster
```

---

#### **3. kubectl** (Kubernetes CLI)

```bash
# Installation (Snap)
sudo snap install kubectl --classic

# Oder: Binary-Download
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Auto-Completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
```

**Agent-Nutzung:**
```bash
kubectl apply -k apps/chat-saas/tenants/demo/
kubectl wait --for=condition=ready pod -l app=chat-saas -n tenant-demo --timeout=300s
kubectl logs -f deployment/chat-saas -n tenant-demo
```

---

#### **4. Flux CLI** (GitOps-Engine)

```bash
# Installation
curl -s https://fluxcd.io/install.sh | sudo bash

# Pre-Check (vor Bootstrap)
flux check --pre

# Bootstrap (lokal für Testing)
flux bootstrap github \
  --owner=ADASK-B \
  --repository=agent-ready-k8s-stack \
  --branch=main \
  --path=clusters/local \
  --personal
```

**Warum Flux statt ArgoCD?**
- ✅ **CLI-First** (agent-freundlicher)
- ✅ **Leichtgewichtig** (keine UI-Server nötig)
- ✅ **Deklarativ** (alles in YAML)
- ✅ **CNCF Graduated** (Production-ready)

**Agent-Nutzung:**
```bash
flux create source git myapp --url=https://github.com/ADASK-B/agent-ready-k8s-stack
flux create kustomization tenant-demo --source=myapp --path="./apps/chat-saas/tenants/demo"
flux reconcile kustomization tenant-demo --with-source
```

---

#### **5. Helm** (Package Manager)

```bash
# Installation
sudo snap install helm --classic

# Oder: Script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Agent-Nutzung:**
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
helm upgrade ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx
```

---

### **Security & Validation Tools (Empfohlen)**

#### **6. Trivy** (Container & Manifest Scanner)

```bash
# Installation (APT)
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy
```

**Agent-Nutzung:**
```bash
# Container-Scan
trivy image ghcr.io/ADASK-B/chat-saas:latest --severity HIGH,CRITICAL --exit-code 1

# Kubernetes-Manifest-Scan
trivy config apps/chat-saas/base/ --severity HIGH,CRITICAL

# SBOM generieren
trivy image --format cyclonedx ghcr.io/ADASK-B/chat-saas:latest > sbom.json
```

---

#### **7. Gitleaks** (Secret Scanner)

```bash
# Installation
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

**Agent-Nutzung:**
```bash
# Scan gesamtes Repo
gitleaks detect --source . --verbose --exit-code 1

# Scan nur Commit
gitleaks protect --staged --verbose --exit-code 1
```

---

#### **8. kubeconform** (K8s Manifest Validator)

```bash
# Installation
wget https://github.com/yannh/kubeconform/releases/download/v0.6.3/kubeconform-linux-amd64.tar.gz
tar -xzf kubeconform-linux-amd64.tar.gz
sudo mv kubeconform /usr/local/bin/
```

**Agent-Nutzung:**
```bash
kubeconform -strict -summary apps/chat-saas/base/*.yaml
```

---

#### **9. Syft** (SBOM Generator)

```bash
# Installation
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
```

**Agent-Nutzung:**
```bash
syft ghcr.io/ADASK-B/chat-saas:latest -o cyclonedx-json > sbom.json
```

---

#### **10. pre-commit** (Git Hooks Framework)

```bash
# Installation
sudo apt install python3-pip
pip3 install pre-commit

# In Projekt aktivieren
pre-commit install
```

**Agent-Nutzung:**
```bash
# Manuelle Ausführung
pre-commit run --all-files

# Automatisch bei git commit
git commit -m "feat: xyz"  # → pre-commit läuft automatisch
```

---

### **Optional Tools (Performance & Komfort)**

#### **11. Task** (Makefile-Alternative)

```bash
# Installation
sudo snap install task --classic
```

**Warum Task statt Makefile?**
- ✅ **YAML-basiert** (einfacher als Make-Syntax)
- ✅ **Cross-Platform** (Windows, Linux, macOS)
- ✅ **Built-in Parallelisierung**
- ✅ **Bessere Fehlerbehandlung**

**Beispiel Taskfile.yml:**
```yaml
version: '3'
tasks:
  cluster:create:
    desc: Erstellt kind-Cluster
    cmds:
      - kind create cluster --name agent-k8s-local --config kind-config.yaml
      - kubectl cluster-info
  
  tenant:create:
    desc: Erstellt neuen Tenant
    vars:
      TENANT: '{{.TENANT | default "demo"}}'
    cmds:
      - kubectl create namespace tenant-{{.TENANT}}
      - kubectl apply -f policies/namespace-template/ -n tenant-{{.TENANT}}
```

---

#### **12. k9s** (Terminal UI für K8s)

```bash
sudo snap install k9s
```

**Nutzung:**
```bash
k9s  # Startet TUI
# Shortcuts:
# 0: Pods anzeigen
# 1: Deployments
# l: Logs
# d: Describe
```

---

#### **13. kubectx/kubens** (Context/Namespace Switching)

```bash
sudo apt install kubectx
```

**Nutzung:**
```bash
kubectx kind-agent-k8s-local     # Context wechseln
kubens tenant-demo               # Namespace wechseln
kubectl get pods                 # Zeigt Pods in tenant-demo
```

---

## 🏢 Multi-Tenancy-Strategie

### **2-Level-Isolation: Namespace + Database**

**Szenario:** Du betreibst eine SaaS-Plattform für mehrere Firmen, jede Firma hat mehrere Abteilungen.

| Isolation-Level | Technologie | Use Case | Stärke |
|-----------------|-------------|----------|--------|
| **Firma-Ebene** | **K8s Namespace** | Acme GmbH, Beta AG, Corp Inc | Harte Isolation (Netzwerk, CPU, RAM) |
| **Abteilungs-Ebene** | **PostgreSQL RLS** | HR, IT, Finance, Sales | Weiche Isolation (Performance) |
| **UI** | **Shared Code** | Alle nutzen gleiche UI | Einfaches Deployment |

**Concrete Example:**

```yaml
# Firma: Acme GmbH
Namespace: tenant-acme
├─ Abteilung: HR       → Database: acme_hr      (RLS: department_id='hr-uuid')
├─ Abteilung: IT       → Database: acme_it      (RLS: department_id='it-uuid')
└─ Abteilung: Finance  → Database: acme_finance (RLS: department_id='finance-uuid')

# Firma: Beta AG
Namespace: tenant-beta
├─ Abteilung: Sales    → Database: beta_sales   (RLS: department_id='sales-uuid')
└─ Abteilung: Support  → Database: beta_support (RLS: department_id='support-uuid')
```

**Network-Policy (per Namespace):**
```yaml
# Verhindert Cross-Tenant-Traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-tenant
  namespace: tenant-acme
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: acme       # Nur von eigenem Namespace
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: acme
  - to:                      # DNS/Internet erlauben
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
```

---

## 🎯 Demo-Anwendung: "ChatOps-SaaS"

### **Stack-Entscheidung: Next.js Full-Stack (Vercel AI SDK)**

**Basierend auf:** [vercel/ai-chatbot](https://github.com/vercel/ai-chatbot)

```
┌──────────────────────────────────────────────────────────────────┐
│ Tenant: "demo.localhost"                                         │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Next.js 14 App Router (Full-Stack)                       │  │
│  │  ┌──────────────────┐     ┌──────────────────────────┐    │  │
│  │  │  Frontend        │     │  API Routes              │    │  │
│  │  │  (React RSC)     │────▶│  /api/chat (streaming)   │    │  │
│  │  │  Port: 3000      │◀────│  /api/auth (NextAuth)    │    │  │
│  │  │                  │     │  /api/db (Prisma ORM)    │    │  │
│  │  └──────────────────┘     └──────────────────────────┘    │  │
│  │                                     │                       │  │
│  │                    Vercel AI SDK    │                       │  │
│  │                    (OpenAI/Anthrop.)│                       │  │
│  └─────────────────────────────────────┼───────────────────────┘  │
│                                        ▼                          │
│                          ┌──────────────────────────┐            │
│                          │  PostgreSQL StatefulSet  │            │
│                          │  ┌────────────────────┐  │            │
│                          │  │ Database: demo_main│  │            │
│                          │  │ Tables:            │  │            │
│                          │  │  • users           │  │            │
│                          │  │  • chats           │  │            │
│                          │  │  • messages        │  │            │
│                          │  └────────────────────┘  │            │
│                          │  PersistentVolume: 10Gi  │            │
│                          └──────────────────────────┘            │
└──────────────────────────────────────────────────────────────────┘
```

**Technologie-Details:**

| Komponente | Technologie | Datei/Paket | Zweck |
|------------|-------------|-------------|-------|
| **Frontend** | Next.js 14 + React Server Components | `app/page.tsx` | UI-Rendering |
| **API** | Next.js API Routes | `app/api/chat/route.ts` | Backend-Logik |
| **Streaming** | Vercel AI SDK | `ai` Package | LLM-Response-Streaming |
| **Database ORM** | Prisma | `prisma/schema.prisma` | Type-Safe DB-Zugriff |
| **Auth** | NextAuth.js (Phase 2) | `app/api/auth/[...nextauth]/route.ts` | JWT-Auth |
| **LLM-Provider** | OpenAI API | `openai` Package | Chat-Completion |
| **Styling** | Tailwind CSS + shadcn/ui | `tailwind.config.js` | Modern UI |

**Features (Phase 1 - Ohne Auth):**
- ✅ Multi-Turn-Conversations
- ✅ Streaming-Responses (Server-Sent Events)
- ✅ Persistent Chat-History (PostgreSQL)
- ✅ Markdown-Rendering (Code-Syntax-Highlighting)
- ✅ Mobile-Responsive
- ❌ Auth (kommt Phase 2)
- ❌ Multi-User (kommt Phase 2)

---

## 🔐 Secrets-Management

### **3-Phasen-Strategie**

| Phase | Umgebung | Tool | Begründung |
|-------|----------|------|------------|
| **Phase 1** | Lokal (kind) | **Sealed Secrets** | Verschlüsselte Secrets in Git commitbar |
| **Phase 2** | AKS Staging | **Sealed Secrets** | Gleicher Workflow wie lokal |
| **Phase 3** | AKS Production | **Azure Key Vault + External Secrets Operator** | Enterprise-Secrets-Management |

---

### **Phase 1: Sealed Secrets (Lokal)**

**Installation:**
```bash
# Sealed Secrets Controller im Cluster installieren
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# kubeseal CLI installieren
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/
```

**Agent-Workflow:**
```bash
# 1. Secret erstellen (nicht committen!)
echo -n "sk-proj-abc123..." > openai-api-key.txt

# 2. Sealed Secret erstellen (commitbar!)
kubectl create secret generic llm-api-key \
  --from-file=api-key=openai-api-key.txt \
  --dry-run=client -o yaml \
  | kubeseal -o yaml \
  > apps/chat-saas/base/sealed-secret.yaml

# 3. Committen (verschlüsselt!)
git add apps/chat-saas/base/sealed-secret.yaml
git commit -m "chore: add LLM API key (sealed)"

# 4. Flux applied automatisch → Controller entschlüsselt im Cluster
```

**Beispiel Sealed Secret:**
```yaml
# apps/chat-saas/base/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: llm-api-key
  namespace: tenant-demo
spec:
  encryptedData:
    api-key: AgBh8F3k...verschlüsselt...7dGh2==
  template:
    type: Opaque
```

---

### **Phase 3: Azure Key Vault (Production)**

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: tenant-acme
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: "https://agent-k8s-keyvault.vault.azure.net"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: llm-api-key
  namespace: tenant-acme
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: llm-api-key
    creationPolicy: Owner
  data:
  - secretKey: api-key
    remoteRef:
      key: tenant-acme-openai-key  # Key in Azure Key Vault
```

**Niemals committen:**
```gitignore
# .gitignore
.env
.env.local
*.key
*.pem
kubeconfig
*-secret.yaml  # Nur sealed-secret.yaml committen!
```

---

## 📦 Projekt-Struktur (Komplett)

```
agent-ready-k8s-stack/
├── .github/
│   └── workflows/
│       ├── ci.yml                        # Docker Build + Push
│       └── security-scan.yml             # Trivy + Gitleaks in CI
│
├── apps/
│   └── chat-saas/                        # Vercel AI Chatbot (angepasst)
│       ├── app/                          # Next.js 14 App Router
│       │   ├── api/
│       │   │   ├── chat/route.ts         # LLM-Streaming-API
│       │   │   └── db/route.ts           # DB-API (Prisma)
│       │   ├── layout.tsx
│       │   └── page.tsx                  # Chat-UI
│       ├── components/
│       │   ├── chat-interface.tsx
│       │   ├── message-list.tsx
│       │   └── ui/                       # shadcn/ui Components
│       ├── lib/
│       │   ├── db.ts                     # Prisma Client
│       │   └── ai-config.ts              # OpenAI Setup
│       ├── prisma/
│       │   └── schema.prisma             # DB-Schema
│       ├── public/
│       ├── Dockerfile                    # Multi-Stage Build
│       ├── docker-compose.yml            # Lokales Testing (optional)
│       ├── package.json
│       ├── next.config.js
│       ├── tailwind.config.ts
│       ├── tsconfig.json
│       │
│       ├── base/                         # K8s Base-Manifests (Kustomize)
│       │   ├── deployment.yaml           # Next.js Deployment
│       │   ├── service.yaml              # ClusterIP Service
│       │   ├── postgres-statefulset.yaml # PostgreSQL
│       │   ├── postgres-service.yaml
│       │   ├── sealed-secret.yaml        # OpenAI API Key (verschlüsselt)
│       │   └── kustomization.yaml
│       │
│       └── tenants/                      # Tenant-Overlays
│           ├── tenant-demo/
│           │   ├── kustomization.yaml    # Overlay für Demo
│           │   ├── ingress.yaml          # demo.localhost
│           │   ├── configmap.yaml        # Tenant-Env-Vars
│           │   └── namespace.yaml
│           └── tenant-acme/
│               ├── kustomization.yaml
│               ├── ingress.yaml          # acme.localhost
│               └── departments.yaml      # HR, IT, Finance
│
├── clusters/                             # Flux Cluster-Configs
│   ├── local/                            # Kind-Cluster
│   │   ├── flux-system/
│   │   │   ├── gotk-components.yaml      # Flux Controllers
│   │   │   ├── gotk-sync.yaml
│   │   │   └── kustomization.yaml
│   │   ├── infrastructure.yaml           # GitRepository für Infra
│   │   └── tenants/
│   │       ├── tenant-demo.yaml          # Flux Kustomization
│   │       └── git-repository.yaml       # Source
│   │
│   └── production/                       # AKS-Config (später)
│       ├── flux-system/
│       ├── infrastructure.yaml
│       └── tenants/
│           ├── tenant-acme.yaml
│           └── tenant-beta.yaml
│
├── infrastructure/                       # Shared Components
│   ├── sources/
│   │   ├── git-repository.yaml           # Flux GitRepository
│   │   └── helm-repositories.yaml        # Helm Repos (Ingress, etc.)
│   │
│   ├── controllers/
│   │   ├── ingress-nginx/
│   │   │   ├── base/
│   │   │   │   ├── helmrelease.yaml
│   │   │   │   └── kustomization.yaml
│   │   │   └── overlays/
│   │   │       ├── local/                # kind: NodePort
│   │   │       │   └── values.yaml
│   │   │       └── production/           # AKS: LoadBalancer
│   │   │           └── values.yaml
│   │   │
│   │   ├── sealed-secrets/
│   │   │   ├── helmrelease.yaml
│   │   │   └── kustomization.yaml
│   │   │
│   │   ├── cert-manager/                 # Phase 2
│   │   │   ├── helmrelease.yaml
│   │   │   └── clusterissuer.yaml        # Let's Encrypt
│   │   │
│   │   └── external-secrets/             # Phase 3
│   │       ├── helmrelease.yaml
│   │       └── secretstore.yaml          # Azure KeyVault
│   │
│   └── monitoring/
│       ├── prometheus/
│       │   ├── helmrelease.yaml
│       │   └── servicemonitor.yaml       # Scrape-Configs
│       └── grafana/
│           ├── helmrelease.yaml
│           └── dashboards/
│               ├── cluster-overview.json
│               └── tenant-metrics.json
│
├── policies/                             # Security Policies
│   ├── namespace-template/               # Template für neue Tenants
│   │   ├── networkpolicy-deny-all.yaml   # Default Deny
│   │   ├── networkpolicy-allow-dns.yaml
│   │   ├── resourcequota.yaml            # CPU/Memory-Limits
│   │   └── limitrange.yaml               # Pod-Limits
│   │
│   ├── conftest/                         # OPA Policies
│   │   ├── kubernetes.rego               # Custom Policies
│   │   └── conftest.toml
│   │
│   └── kyverno/                          # K8s-Native Policies (Phase 2)
│       ├── require-labels.yaml
│       ├── disallow-latest-tag.yaml
│       └── require-resource-limits.yaml
│
├── setup-template/                       # Template-Setup-Scripts
│   ├── README.md                         # Script-Dokumentation
│   ├── setup-complete-template.sh        # Master-Script (Block 3-8)
│   ├── 01-install-tools.sh               # Installiert alle Tools
│   ├── 02-setup-template-structure.sh    # Clont Flux Example, erstellt Struktur
│   ├── 03-create-kind-cluster.sh         # Kind-Cluster erstellen
│   ├── 04-deploy-infrastructure.sh       # Ingress-Nginx deployen
│   └── utils/
│       ├── wait-for-ready.sh
│       └── get-logs.sh
│
├── docs/                                 # Zusätzliche Dokumentation
│   ├── SETUP.md                          # Detailliertes Setup
│   ├── TROUBLESHOOTING.md
│   ├── AZURE-DEPLOYMENT.md               # AKS-Guide
│   └── ARCHITECTURE.md
│
├── .pre-commit-config.yaml               # Pre-Commit-Hooks
├── .gitignore
├── .dockerignore
├── Taskfile.yml                          # Agent-Commands
├── kind-config.yaml                      # Kind-Cluster-Config
├── LICENSE
└── README.md                             # Diese Datei
```

---

## ⚡ Quick Start

### **🚀 Schnellstart: Komplette Automation**

```bash
# Repository klonen
git clone https://github.com/ADASK-B/agent-ready-k8s.git
cd agent-ready-k8s

# ROADMAP.md lesen (Phasen-Plan)
cat ROADMAP.md

# Tools installieren (Block 1-2)
# Siehe ROADMAP.md für manuelle Installation

# Komplette Template-Erstellung (Block 3-8)
chmod +x setup-template/setup-complete-template.sh
./setup-template/setup-complete-template.sh

# Ergebnis: http://demo.localhost läuft! 🎉
```

**⏱️ Runtime:** ~20-30 Minuten (einmalig)  
**Ergebnis:** Laufende podinfo-Demo unter http://demo.localhost  
**Nächster Schritt:** Siehe [ROADMAP.md](ROADMAP.md) Phase 1, Block 9

---

### **📋 Oder: Manuelles Setup (Schritt für Schritt)**

### **1. Tools installieren (einmalig)**

```bash
# Repository klonen
git clone https://github.com/ADASK-B/agent-ready-k8s.git
cd agent-ready-k8s

# Alle Tools installieren (Docker, kind, kubectl, Flux, etc.)
# Siehe ROADMAP.md Block 1-2 für detaillierte Befehle

# Reboot (für Docker-Gruppe)
sudo reboot
```

### **2. Lokalen Cluster erstellen**

```bash
# Kind-Cluster erstellen + Flux bootstrappen
task cluster:create

# Warten bis Flux bereit ist
flux check

# Infrastructure deployen (Ingress-Nginx, Sealed Secrets)
task infra:deploy

# Status prüfen
kubectl get pods -A
```

### **3. Demo-Tenant erstellen**

```bash
# Tenant erstellen (Namespace + Policies + Flux Kustomization)
task tenant:create TENANT=demo DOMAIN=demo.localhost

# OpenAI API Key setzen (als Sealed Secret)
export OPENAI_API_KEY="sk-proj-abc123..."
task secret:create TENANT=demo KEY=llm-api-key VALUE=$OPENAI_API_KEY

# Warten bis Deployment bereit
kubectl wait --for=condition=available deployment/chat-saas -n tenant-demo --timeout=300s

# Chat öffnen
echo "Chat läuft auf: http://demo.localhost"
curl http://demo.localhost
```

### **4. Entwickeln & Testen**

```bash
# Code ändern
vim apps/chat-saas/app/page.tsx

# Container bauen & in lokale Registry pushen
task dev:build TENANT=demo

# Flux reconcile (manuell triggern)
task flux:reconcile TENANT=demo

# Logs anschauen
task tenant:logs TENANT=demo

# Shell im Pod
task tenant:shell TENANT=demo
```

### **5. Security-Checks & Commit**

```bash
# Security-Scans laufen
task security:scan

# Pre-Commit-Hooks aktivieren
pre-commit install

# Committen (Pre-Commit läuft automatisch)
git add .
git commit -m "feat: improved chat UI"

# Wenn Checks grün: Pushen
git push origin main
```

### **6. Cleanup**

```bash
# Tenant löschen
task tenant:delete TENANT=demo

# Kompletten Cluster löschen
task cluster:delete
```

---

## 🚀 Lokaler Entwicklungs-Workflow (Detailliert)

### **Schritt 1: Code-Änderung**

```bash
# Chat-UI verbessern
vim apps/chat-saas/app/page.tsx

# Neue Abhängigkeit hinzufügen
cd apps/chat-saas
npm install @radix-ui/react-dialog
```

### **Schritt 2: Lokaler Build & Test**

```bash
# Docker Build
cd apps/chat-saas
docker build -t chat-saas:dev .

# Lokal testen (ohne K8s)
docker run -p 3000:3000 -e OPENAI_API_KEY=$OPENAI_API_KEY chat-saas:dev
# http://localhost:3000

# Oder: Mit docker-compose (inkl. PostgreSQL)
docker-compose up
```

### **Schritt 3: K8s-Deploy & Test**

```bash
# Container in lokale Registry pushen (kind-spezifisch)
kind load docker-image chat-saas:dev --name agent-k8s-local

# Deployment updaten
kubectl set image deployment/chat-saas chat-saas=chat-saas:dev -n tenant-demo

# Oder: Via Flux (GitOps-Way)
vim apps/chat-saas/tenants/tenant-demo/kustomization.yaml
# newTag: dev
flux reconcile kustomization tenant-demo --with-source

# Warten & Logs
kubectl rollout status deployment/chat-saas -n tenant-demo
kubectl logs -f deployment/chat-saas -n tenant-demo
```

### **Schritt 4: Security-Scans**

```bash
# Container scannen
trivy image chat-saas:dev --severity HIGH,CRITICAL --exit-code 1

# K8s-Manifeste scannen
trivy config apps/chat-saas/base/ --severity HIGH,CRITICAL

# Secrets scannen
gitleaks detect --source . --verbose --exit-code 1

# Manifeste validieren
kubeconform -strict apps/chat-saas/base/*.yaml

# Policies prüfen (OPA)
conftest test apps/chat-saas/base/*.yaml -p policies/conftest/

# SBOM generieren
syft chat-saas:dev -o cyclonedx-json > sbom.json
```

### **Schritt 5: Git-Workflow**

```bash
# Branch erstellen
git checkout -b feature/improved-ui

# Pre-Commit-Hooks testen (manuell)
pre-commit run --all-files

# Committen (Hooks laufen automatisch)
git add apps/chat-saas/
git commit -m "feat: improved chat UI with better UX"

# Push
git push origin feature/improved-ui

# Pull Request erstellen (GitHub/GitLab)
# → CI-Pipeline läuft (Docker Build, Trivy, Tests)
```

---

## 🌐 Cloud-Deployment (AKS)

### **Einmalige AKS-Setup**

```bash
# 1. Azure CLI installieren
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 2. Login
az login

# 3. Resource Group erstellen
az group create --name agent-k8s-rg --location westeurope

# 4. AKS-Cluster erstellen (Free Tier)
az aks create \
  --resource-group agent-k8s-rg \
  --name agent-k8s-prod \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys \
  --tier free

# 5. Credentials holen
az aks get-credentials --resource-group agent-k8s-rg --name agent-k8s-prod

# 6. Flux im AKS bootstrappen
flux bootstrap github \
  --owner=ADASK-B \
  --repository=agent-ready-k8s-stack \
  --branch=main \
  --path=clusters/production \
  --personal

# Fertig! Flux schaut jetzt auf Git-Repo
```

### **Ab jetzt: Git Push = Auto-Deploy**

```bash
# Lokal entwickeln
vim apps/chat-saas/app/page.tsx

# Commit & Push
git commit -am "feat: improved UI"
git push origin main

# 🎉 Flux deployed automatisch in AKS (5-10 min)
# Status prüfen:
flux get kustomizations
kubectl get pods -n tenant-acme
```

---

## 🤝 Agent-Commands (Taskfile.yml)

### **Cluster-Management**

```bash
# Cluster erstellen
task cluster:create              # Kind-Cluster + Flux Bootstrap

# Cluster-Info
task cluster:info                # Nodes, Pods, Ressourcen

# Cluster löschen
task cluster:delete              # Kompletter Teardown
```

### **Tenant-Management**

```bash
# Tenant erstellen
task tenant:create TENANT=acme DOMAIN=acme.localhost

# Abteilung hinzufügen
task department:create TENANT=acme DEPARTMENT=hr DATABASE=acme_hr

# Tenant auflisten
task tenant:list                 # Alle Tenants anzeigen

# Tenant-Logs
task tenant:logs TENANT=acme     # Alle Pods

# Shell im Pod
task tenant:shell TENANT=acme POD=chat-saas

# Tenant löschen
task tenant:delete TENANT=acme   # Namespace + alle Ressourcen
```

### **Flux GitOps**

```bash
# Flux-Status
task flux:status                 # Alle Kustomizations

# Manuelles Reconcile
task flux:reconcile TENANT=acme  # Jetzt deployen (nicht warten)

# Reconciliation pausieren
task flux:suspend TENANT=acme

# Fortsetzen
task flux:resume TENANT=acme
```

### **Security & Validation**

```bash
# Alle Scans
task security:scan               # Trivy + Gitleaks + kubeconform

# Nur Container-Scan
task security:trivy IMAGE=chat-saas:latest

# Nur Secret-Scan
task security:gitleaks

# Report generieren
task security:report             # JSON + HTML

# SBOM erstellen
task security:sbom IMAGE=chat-saas:latest
```

### **Development**

```bash
# Container bauen
task dev:build TENANT=acme

# In Registry pushen
task dev:push TENANT=acme IMAGE=chat-saas:v1.2.3

# Integration-Tests
task dev:test TENANT=acme

# Port-Forward
task dev:forward TENANT=acme PORT=3000
```

### **Monitoring**

```bash
# Grafana öffnen
task monitoring:open             # http://localhost:3000

# Prometheus-Query
task monitoring:prometheus QUERY='up{namespace="tenant-acme"}'

# Logs aggregieren
task monitoring:logs TENANT=acme SINCE=1h
```

---

## 🔍 Troubleshooting

### **Problem: Kind-Cluster startet nicht**

```bash
# Fehler: "failed to create cluster"
# Lösung: Docker läuft nicht
sudo systemctl start docker
sudo systemctl enable docker

# Fehler: "address already in use"
# Lösung: Alter Cluster existiert noch
kind delete cluster --name agent-k8s-local
```

### **Problem: Flux reconcile failt**

```bash
# Fehler anzeigen
flux get kustomizations
flux logs

# Häufige Ursachen:
# 1. Git-Repo nicht erreichbar
flux get sources git
# → Prüfe GitHub-Token

# 2. Kustomize-Syntax-Fehler
kubectl apply -k apps/chat-saas/base/ --dry-run=server
# → Zeigt YAML-Fehler

# 3. Image nicht pullbar
kubectl describe pod -n tenant-demo | grep -A5 "Failed to pull"
# → Prüfe ImagePullSecret
```

### **Problem: Pod crasht**

```bash
# Logs anschauen
kubectl logs -f deployment/chat-saas -n tenant-demo --previous

# Events prüfen
kubectl get events -n tenant-demo --sort-by='.lastTimestamp'

# Beschreibung
kubectl describe pod <pod-name> -n tenant-demo

# Häufige Ursachen:
# 1. OOMKilled → Erhöhe memory-Limit
# 2. CrashLoopBackOff → Prüfe Logs
# 3. ImagePullBackOff → Prüfe Image-Tag
```

### **Problem: Ingress funktioniert nicht**

```bash
# Ingress-Status
kubectl get ingress -A
kubectl describe ingress chat-saas-ingress -n tenant-demo

# Ingress-Controller-Logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# /etc/hosts prüfen (lokal)
cat /etc/hosts | grep localhost
# Sollte enthalten: 127.0.0.1 demo.localhost

# Manuell hinzufügen:
echo "127.0.0.1 demo.localhost" | sudo tee -a /etc/hosts
```

### **Problem: Secret nicht entschlüsselt**

```bash
# Sealed Secret Status
kubectl get sealedsecrets -A

# Controller-Logs
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Häufige Ursache: Controller nicht installiert
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

---

## 💰 Kosten-Kalkulation

### **Lokal (kind auf Ubuntu)**

| Ressource | Kosten |
|-----------|--------|
| Hardware | **0 €** (dein Laptop/PC) |
| Software | **0 €** (100% Open Source) |
| Cloud | **0 €** (nichts in Cloud) |
| **TOTAL** | **0 € / Monat** |

### **AKS Production (Minimal-Setup)**

| Ressource | Spezifikation | Kosten/Monat (ca.) |
|-----------|---------------|---------------------|
| **AKS Control Plane** | Free Tier | **0 €** |
| **Worker Nodes** | 3x Standard_B2s (2 vCPU, 4 GB RAM) | **~60 €** |
| **Managed Disks** | 3x 128 GB Premium SSD | **~30 €** |
| **Load Balancer** | Standard | **~20 €** |
| **Bandbreite** | 100 GB Egress | **~8 €** |
| **Backup (optional)** | Azure Backup | **~10 €** |
| **TOTAL** | | **~128 € / Monat** |

**Mit Azure Free Account:**
- ✅ **200 € Startguthaben** → ~1,5 Monate kostenlos
- ✅ Dann **Pay-as-you-go**

**Sparpotenzial:**
- Spot-Instances: **-70%** (aber nicht für Production)
- Reserved Instances (1 Jahr): **-30%**
- Dev/Test-Subscription: **-20%**

---

## 📚 Weiterführende Schritte

### **Phase 2: Auth & Multi-User**

```bash
# NextAuth.js integrieren
task app:add-auth TENANT=acme PROVIDER=github

# Oder: Keycloak (Enterprise)
task infra:add-keycloak
```

### **Phase 3: Monitoring & Alerting**

```bash
# Prometheus + Grafana deployen
task monitoring:deploy

# Alertmanager konfigurieren
task monitoring:alert EMAIL=ops@company.com
```

### **Phase 4: CI/CD-Pipeline**

```bash
# GitHub Actions einrichten
task ci:setup REGISTRY=ghcr.io

# Azure DevOps Pipeline
task ci:azure SUBSCRIPTION=<subscription-id>
```

### **Phase 5: Disaster Recovery**

```bash
# Velero (Cluster-Backups)
task backup:setup BUCKET=s3://backups

# Database-Backups
task db:backup SCHEDULE="0 2 * * *"  # Täglich 2 Uhr
```

---

## 📝 Lizenz

MIT License - siehe [LICENSE](LICENSE)

---

## 🙏 Credits & Attributions

This template is built upon best practices from leading open-source projects:

- **[FluxCD flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)** (Apache-2.0)  
  → GitOps patterns, Kustomize layouts, repository structure
  
- **[podinfo](https://github.com/stefanprodan/podinfo)** by Stefan Prodan (Apache-2.0)  
  → Demo application for testing Kubernetes deployments
  
- **[AKS Baseline Automation](https://github.com/Azure/aks-baseline-automation)** by Microsoft (MIT)  
  → Azure Kubernetes Service best practices (Phase 2 only)

- **[helm/kind-action](https://github.com/helm/kind-action)** by The Helm Authors (Apache-2.0)  
  → CI/CD testing with ephemeral kind clusters (Phase 2 only)

See [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) for full attribution and license details.

---

## 🤝 Contributing

Pull Requests willkommen! Siehe [CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/ADASK-B/agent-ready-k8s-stack/issues)
- **Discussions:** [GitHub Discussions](https://github.com/ADASK-B/agent-ready-k8s-stack/discussions)
- **Docs:** [docs/](docs/)

---

**🎉 Happy Shipping!** Gebaut mit ❤️ für Agent-gesteuerte Entwicklung.
