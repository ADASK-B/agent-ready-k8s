# 🗺️ Roadmap - agent-ready-k8s

**Project Goal:** Build a scalable, AI-agent-friendly Kubernetes template stack with GitOps, Hot-Reload capabilities, and multi-tenant support.

---

## 📋 Phase 0: Template Foundation (Local Development)

**Goal:** Create a complete local Kubernetes foundation with databases, GitOps, and reference application.

**Status:** 🏗️ In Development

### Block 1: Tool Installation & Validation
- [ ] Install Docker Engine CE
- [ ] Install kind (Kubernetes IN Docker)
- [ ] Install kubectl
- [ ] Install Helm
- [ ] Install Argo CD CLI
- [ ] Install k9s (optional)
- [ ] Install Task runner (optional)
- [ ] Validate all tool installations with tests

### Block 2: Project Structure Creation
- [ ] Create GitOps folder structure (apps/, clusters/, infrastructure/, policies/)
- [ ] Create app base manifests directory (apps/podinfo/base/)
- [ ] Create tenant overlay directory (apps/podinfo/tenants/demo/)
- [ ] Create cluster configurations (clusters/local/, clusters/production/)
- [ ] Create infrastructure sources directory
- [ ] Create infrastructure controllers directory
- [ ] Create policy templates
- [ ] Generate kind cluster configuration (kind-config.yaml)
- [ ] Add .gitkeep files to maintain structure
- [ ] Validate folder structure

### Block 3: Template Manifests Cloning
- [ ] Clone podinfo repository from GitHub
- [ ] Extract Kubernetes manifests from podinfo
- [ ] Copy base manifests to apps/podinfo/base/
- [ ] Create kustomization.yaml for base
- [ ] Create tenant overlay for demo namespace
- [ ] Configure tenant-specific settings
- [ ] Validate manifest structure
- [ ] Clean up temporary files

### Block 4: Kubernetes Cluster Creation
- [ ] Create kind cluster with custom config
- [ ] Configure port mappings (80:80, 443:443)
- [ ] Wait for cluster to be ready
- [ ] Verify node status
- [ ] Verify system pods running
- [ ] Validate kubectl connectivity
- [ ] Check Kubernetes version

### Block 5: Ingress Controller Deployment
- [ ] Add ingress-nginx Helm repository
- [ ] Create ingress-nginx namespace
- [ ] Deploy ingress-nginx via Helm (NodePort for kind)
- [ ] Wait for ingress controller pod to be ready
- [ ] Verify ingress service created
- [ ] Verify admission webhook configured
- [ ] Test ingress controller readiness

### Block 6: Database Deployment (PostgreSQL + Redis)
- [ ] Create demo-platform namespace with labels
- [ ] Add Bitnami Helm repository
- [ ] Deploy PostgreSQL (Bitnami chart)
  - [ ] Configure credentials (demouser/demopass/demodb)
  - [ ] Set up persistent storage
  - [ ] Wait for PostgreSQL pod to be ready
- [ ] Deploy Redis (Bitnami chart)
  - [ ] Configure password (redispass)
  - [ ] Set up master configuration
  - [ ] Wait for Redis pod to be ready
- [ ] Test PostgreSQL connection (kubectl exec)
- [ ] Test Redis connection (kubectl exec)
- [ ] Validate both databases operational

### Block 7: Argo CD Deployment (GitOps)
- [ ] Create argocd namespace
- [ ] Apply Argo CD manifests (v2.12.3)
- [ ] Patch argocd-server service for Ingress
- [ ] Create Ingress for argocd.local
- [ ] Wait for Argo CD pods to be ready (all 7 pods)
- [ ] Retrieve admin password from secret
- [ ] Verify Argo CD server readiness
- [ ] Validate Ingress configuration
- [ ] Test admin password retrieval
- [ ] Document access credentials

### Block 8: podinfo Demo Application Deployment
- [ ] Create tenant-demo namespace with label
- [ ] Add podinfo Helm repository
- [ ] Deploy podinfo v6.9.2 via Helm
  - [ ] Configure 2 replicas
  - [ ] Connect to Redis (redis-master.demo-platform:6379)
  - [ ] Set Redis password
- [ ] Create Ingress for demo.localhost
- [ ] Wait for podinfo pods to be ready
- [ ] Verify Helm release status
- [ ] Validate pod count and readiness
- [ ] Verify service ClusterIP
- [ ] Validate Ingress configuration

### Phase 0 Completion Tasks
- [ ] Run complete Phase 0 setup (setup-phase0.sh)
- [ ] Verify all 65 tests pass (100%)
- [ ] Add domains to /etc/hosts (demo.localhost, argocd.local)
- [ ] Test podinfo HTTP endpoint
- [ ] Test Argo CD HTTP endpoint
- [ ] Login to Argo CD web UI
- [ ] Verify PostgreSQL and Redis connectivity
- [ ] Document all credentials and access URLs
- [ ] Create Phase 0 completion documentation
