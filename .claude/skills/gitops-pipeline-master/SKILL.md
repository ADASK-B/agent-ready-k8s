---
name: gitops-pipeline-master
description: Design and implement GitOps workflows with ArgoCD and CI/CD pipelines. Use for GitHub Actions, image promotion, rollout strategies, and deployment automation. Keywords: GitOps, ArgoCD, CI/CD, GitHub Actions, deployment, rollout, canary, blue-green.
---

# GitOps Pipeline Master

Expert in designing GitOps-based deployment workflows with Argo CD and CI/CD automation.

## When to Use This Skill

- Setting up Argo CD Applications and ApplicationSets
- Designing App-of-Apps patterns
- Creating GitHub Actions CI workflows
- Implementing image promotion strategies
- Configuring rollout strategies (canary, blue-green)
- Setting up automated deployments
- Debugging sync issues and deployment failures

---

## GitOps Principles

1. **Declarative** - Desired state defined in Git
2. **Versioned** - All changes tracked in Git history
3. **Automated** - Changes applied automatically
4. **Auditable** - Git provides complete audit trail

```
Developer → Git Push → CI (Build/Test/Push) → Git Update → ArgoCD Sync → Cluster
```

---

## Argo CD Architecture

```
┌────────────────────────────────────────────────────┐
│                   Git Repository                    │
│  ┌───────────────┐  ┌───────────────────────────┐  │
│  │ apps/         │  │ clusters/                 │  │
│  │   my-app/     │  │   overlays/               │  │
│  │     base/     │  │     kind/                 │  │
│  │     overlays/ │  │     prod/                 │  │
│  └───────────────┘  └───────────────────────────┘  │
└────────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                    Argo CD                          │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────┐   │
│  │ Root App    │→ │ Infra Apps  │→ │ App Apps  │   │
│  │ (bootstrap) │  │ (addons)    │  │ (services)│   │
│  └─────────────┘  └─────────────┘  └───────────┘   │
└────────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                  │
└────────────────────────────────────────────────────┘
```

---

## App-of-Apps Pattern

### Root Application

```yaml
# argocd/bootstrap/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Child Applications

```yaml
# argocd/apps/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploy before apps
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD
    path: clusters/overlays/prod/infrastructure
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## ApplicationSet for Multi-Environment

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            cluster: https://dev-cluster:6443
          - env: staging
            cluster: https://staging-cluster:6443
          - env: prod
            cluster: https://prod-cluster:6443

  template:
    metadata:
      name: 'my-app-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        targetRevision: HEAD
        path: 'apps/my-app/overlays/{{env}}'
      destination:
        server: '{{cluster}}'
        namespace: my-app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## Sync Waves

Control deployment order with sync waves:

```yaml
# Wave -2: CRDs
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
# Wave -1: Operators, Infrastructure
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
---
# Wave 0: Core services (default)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# Wave 1: Applications
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

---

## GitHub Actions CI Workflow

### Build and Push

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'Dockerfile'
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Update Deployment Manifest

```yaml
# .github/workflows/deploy.yaml
name: Deploy

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]

jobs:
  update-manifest:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.PAT_TOKEN }}  # Needs write access

      - name: Get image digest
        id: digest
        run: |
          DIGEST=$(docker manifest inspect ghcr.io/${{ github.repository }}:${{ github.sha }} -v | jq -r '.Descriptor.digest')
          echo "digest=$DIGEST" >> $GITHUB_OUTPUT

      - name: Update kustomization
        run: |
          cd apps/my-app/overlays/dev
          kustomize edit set image ghcr.io/${{ github.repository }}@${{ steps.digest.outputs.digest }}

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore: update image to ${{ github.sha }}"
          git push
```

---

## Image Promotion Strategy

```
┌─────────┐    ┌─────────┐    ┌─────────┐
│   Dev   │ → │ Staging │ → │  Prod   │
│  (auto) │    │ (auto)  │    │(manual) │
└─────────┘    └─────────┘    └─────────┘
     │              │              │
     ▼              ▼              ▼
  PR merge     Tests pass      Approval
  triggers     triggers        + tag
```

### Promotion Workflow

```yaml
# .github/workflows/promote.yaml
name: Promote

on:
  workflow_dispatch:
    inputs:
      source_env:
        description: 'Source environment'
        required: true
        type: choice
        options:
          - dev
          - staging
      target_env:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - prod

jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.PAT_TOKEN }}

      - name: Get current image
        id: current
        run: |
          IMAGE=$(kustomize build apps/my-app/overlays/${{ inputs.source_env }} | grep "image:" | awk '{print $2}')
          echo "image=$IMAGE" >> $GITHUB_OUTPUT

      - name: Update target environment
        run: |
          cd apps/my-app/overlays/${{ inputs.target_env }}
          kustomize edit set image ${{ steps.current.outputs.image }}

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore: promote ${{ inputs.source_env }} to ${{ inputs.target_env }}"
          git push
```

---

## Rollout Strategies

### Canary with Argo Rollouts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: ghcr.io/org/my-app:v1.0.0
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 25
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100
      canaryService: my-app-canary
      stableService: my-app-stable
```

### Blue-Green

```yaml
strategy:
  blueGreen:
    activeService: my-app-active
    previewService: my-app-preview
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30
```

---

## Sync Options Reference

```yaml
syncPolicy:
  automated:
    prune: true           # Delete resources not in Git
    selfHeal: true        # Revert manual changes
    allowEmpty: false     # Fail if app has no resources

  syncOptions:
    - CreateNamespace=true
    - PruneLast=true           # Prune after sync
    - ApplyOutOfSyncOnly=true  # Only sync changed resources
    - Replace=true             # Use kubectl replace
    - ServerSideApply=true     # Use server-side apply

  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

---

## Best Practices

### DO:
- Use image digests, not tags
- Implement sync waves for dependencies
- Use ApplicationSets for multi-env
- Separate config repos from app repos
- Enable automated sync with selfHeal
- Use kustomize for environment differences
- Sign commits and images

### DON'T:
- Manually edit manifests on cluster
- Use `latest` tags
- Sync to cluster from local machine
- Store secrets in Git (use ESO)
- Deploy without health checks
- Skip staging environment

---

## Related References

- [references/argocd-patterns.md](references/argocd-patterns.md) - Advanced Argo CD patterns
- [references/github-actions.md](references/github-actions.md) - CI workflow templates
- [references/image-promotion.md](references/image-promotion.md) - Promotion strategies
