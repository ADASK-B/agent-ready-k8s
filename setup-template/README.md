# 🛠️ Setup-Template Scripts Documentation

This directory contains automation scripts for the agent-ready-k8s template setup.

---

## 🚀 Quick Start

**Complete Setup (recommended):**
```bash
./setup-template/setup-complete-template.sh
```
This runs ROADMAP Blocks 3-8 and gives you a running demo at `http://demo.localhost`

**Individual Scripts:** See below for granular control

---

## 📋 Script Overview

### **Phase 1: Local Development**

| Script | ROADMAP Block | Purpose | Runtime |
|--------|---------------|---------|---------|
| **`setup-complete-template.sh`** | **Block 3-8** | **Complete automation: Structure → Cluster → Demo** | **~20-30 min** |
| `01-install-tools.sh` | Block 1-2 | Install all required tools (Docker, kind, kubectl, Helm, etc.) | ~30 min |
| `02-setup-template-structure.sh` | Block 4 | Clone Flux Example, copy podinfo structure, create licenses | ~5 min |
| `03-create-kind-cluster.sh` | Block 5 | Create local kind cluster with ingress support | ~10 min |
| `04-deploy-infrastructure.sh` | Block 6 | Deploy Ingress-Nginx, Sealed Secrets | ~15 min |

## Phase 2: Cloud Deployment (Future)

| Script | Description | When to use |
|--------|-------------|-------------|
| `10-setup-github-actions.sh` | Creates GitHub Actions workflows | ROADMAP Block 10 (Future) |
| `11-bootstrap-flux.sh` | Bootstraps Flux in cluster | ROADMAP Block 11 (Future) |
| `12-setup-aks.sh` | Creates AKS cluster in Azure | ROADMAP Block 12 (Future) |

## Usage

### Make scripts executable:
```bash
chmod +x scripts/*.sh
```

### Run individual scripts:
```bash
# Block 4: Setup template structure
./scripts/02-setup-template-structure.sh
```

### Or use Task automation:
```bash
# If Taskfile.yml is configured:
task setup:template
```

## Script Conventions

- **Exit codes:**
  - `0` = Success
  - `1` = Error
  - `2` = Warning (non-critical)

- **Logging:**
  - `[INFO]` = Informational messages
  - `[✓]` = Success
  - `[⚠]` = Warning
  - `[✗]` = Error

- **Safety:**
  - All scripts use `set -euo pipefail` for error handling
  - Temp files are cleaned up automatically
  - Dry-run mode where applicable

---

**Note:** Scripts are designed to be idempotent (safe to run multiple times).
