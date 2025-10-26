# Local Development Guide

## Overview

This repository uses **GitOps** principles: everything is declared in Git, and Argo CD automatically syncs changes to your local Kubernetes cluster.

---

## Prerequisites

Install these tools before starting:

| Tool | Purpose | Why Needed | Installation |
|------|---------|------------|--------------|
| **Docker** | Container runtime | Run kind cluster | [docker.com](https://docs.docker.com/get-docker/) |
| **kind** | Local Kubernetes | Development cluster | `brew install kind` or [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/) |
| **kubectl** | K8s CLI | Interact with cluster | `brew install kubectl` or [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | Package manager | Install charts | `brew install helm` or [helm.sh](https://helm.sh/docs/intro/install/) |
| **Argo CD CLI** | GitOps tool | Manage applications | `brew install argocd` or [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/en/stable/cli_installation/) |
| **Git** | Version control | Clone repo | Pre-installed on most systems |

**Optional but recommended:**
- **k9s** - Terminal UI for Kubernetes: `brew install k9s`
- **kubectx/kubens** - Switch contexts/namespaces: `brew install kubectx`

---

## Tech Stack

| Component | Technology | Purpose | Why This Choice |
|-----------|-----------|---------|-----------------|
| **Kubernetes** | kind (local) | Container orchestration | Industry standard, local dev with kind is fast |
| **GitOps** | Argo CD | Declarative deployments | Audit trail, rollback, drift detection |
| **Ingress** | NGINX Ingress | External access | Stable, well-documented, works everywhere |
| **Database** | PostgreSQL | Persistent data | ACID compliance, SQL, proven reliability |
| **Cache** | Redis | Hot-reload, Pub/Sub | Fast, simple, widely supported |
| **Registry** | GHCR/Harbor | Image storage | Free (GHCR), self-hosted option (Harbor) |
| **IaC** | Terraform | Infrastructure provisioning | State management, cloud-agnostic |

---

## Development Workflow

### 1. Clone Repository

```bash
git clone https://github.com/ADASK-B/agent-ready-k8s.git
cd agent-ready-k8s
```

### 2. Start Local Cluster

```bash
# Create kind cluster (see setup-template/phase0-template-foundation/)
kind create cluster --config kind-config.yaml

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 3. Deploy Infrastructure via GitOps

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply root application (app-of-apps pattern)
kubectl apply -f argocd/root-app.yaml

# Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# User: admin
# Password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### 4. Make Changes (GitOps Flow)

```bash
# 1. Edit manifests
vim apps/podinfo/base/deployment.yaml

# 2. Commit changes
git add apps/podinfo/
git commit -m "feat: update podinfo replicas to 3"

# 3. Push to Git
git push origin main

# 4. Argo CD syncs automatically (or manual sync)
argocd app sync podinfo
```

---

## Common Tasks

### View All Applications

```bash
kubectl get applications -n argocd
```

### Check Application Status

```bash
argocd app get podinfo
```

### Sync Application Manually

```bash
argocd app sync podinfo --prune
```

### Access Services Locally

```bash
# PostgreSQL
kubectl port-forward svc/postgresql -n demo-platform 5432:5432

# Redis
kubectl port-forward svc/redis -n demo-platform 6379:6379

# Podinfo
kubectl port-forward svc/podinfo -n demo-platform 9898:9898
```

### View Logs

```bash
# Argo CD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Application logs
kubectl logs -n demo-platform deployment/podinfo -f
```

### Troubleshooting

```bash
# Check pod status
kubectl get pods -A

# Describe failing pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## Directory Structure (Key Files)

```
agent-ready-k8s/
├── apps/                          # Application manifests
│   ├── base/                      # Base Argo CD Applications
│   └── <service>/                 # Per-service configs
├── clusters/                      # Environment configs
│   └── local/                     # Local cluster overlay
├── helm-charts/infrastructure/    # Vendored Helm charts
│   ├── ingress-nginx/
│   ├── postgresql/
│   └── redis/
├── argocd/                        # Argo CD setup
│   └── root-app.yaml              # App-of-apps entry point
└── setup-template/                # Phase-specific setup scripts
    └── phase0-template-foundation/
```

---

## Best Practices

### GitOps Principles

1. **Git is Source of Truth** - All changes via Git commits
2. **Declarative** - Describe desired state, not steps
3. **Automated Sync** - Argo CD handles deployment
4. **Version Control** - Every change is auditable

### Local Development

- ✅ Use `kubectl apply -k` to test Kustomize locally before pushing
- ✅ Run `helm template` to preview chart output
- ✅ Use `argocd app diff` to see what will change
- ❌ Avoid manual `kubectl apply` for managed resources
- ❌ Don't commit secrets (use sealed secrets or External Secrets Operator)

### Testing Changes

```bash
# 1. Render manifests locally
kustomize build apps/podinfo/base

# 2. Validate with kubeconform
kustomize build apps/podinfo/base | kubeconform --strict

# 3. Apply to test namespace
kubectl create namespace test
kustomize build apps/podinfo/base | kubectl apply -n test -f -

# 4. Clean up
kubectl delete namespace test
```

---

## Next Steps

- **Phase-specific setup:** See `setup-template/phase*/` for detailed phase instructions
- **Architecture:** See `docs/architecture/ARCHITECTURE.md` for design decisions
- **Runbooks:** See `docs/runbooks/` for operational procedures

---

## Quick Reference

| Task | Command |
|------|---------|
| List all apps | `kubectl get applications -n argocd` |
| Sync app | `argocd app sync <app-name>` |
| View app status | `argocd app get <app-name>` |
| Port-forward service | `kubectl port-forward svc/<service> -n <namespace> <local-port>:<remote-port>` |
| View logs | `kubectl logs -n <namespace> deployment/<name> -f` |
| Restart deployment | `kubectl rollout restart deployment/<name> -n <namespace>` |
