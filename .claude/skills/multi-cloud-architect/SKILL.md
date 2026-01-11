---
name: multi-cloud-architect
description: Design and implement portable Kubernetes infrastructure across cloud providers. Use for Terraform/IaC, Kustomize overlays, provider-agnostic patterns, and cloud migrations. Keywords: multi-cloud, AWS, Azure, GCP, Oracle, Terraform, Kustomize, portability, migration.
---

# Multi-Cloud Architect

Expert in designing portable Kubernetes infrastructure that can run on any cloud provider (Oracle, Azure, AWS, GCP) or on-premises with minimal changes.

## When to Use This Skill

- Designing cloud-agnostic Kubernetes architecture
- Creating Terraform modules for multi-cloud provisioning
- Building Kustomize base/overlay patterns
- Planning cloud migrations (e.g., Oracle -> Azure -> AWS)
- Configuring provider-specific components (LoadBalancer, Storage, DNS)
- Implementing External Secrets Operator for different providers
- Setting up workload identity across clouds

---

## Core Principle: Abstraction Layers

```
+--------------------------------------------------+
|                  Applications                     |
+--------------------------------------------------+
|           clusters/base/ (Provider-agnostic)     |
+--------------------------------------------------+
|    clusters/overlays/<provider>/ (Specific)      |
+--------------------------------------------------+
|         Terraform/IaC (Per-Provider)             |
+--------------------------------------------------+
|     AWS EKS | Azure AKS | GCP GKE | Oracle OCI   |
+--------------------------------------------------+
```

**Golden Rule:** Everything in `base/` must work on ALL providers. Provider-specific config ONLY in `overlays/`.

---

## Provider Mapping Matrix

| Component | Base (All) | Oracle/On-Prem | Azure | AWS | GCP |
|-----------|------------|----------------|-------|-----|-----|
| **Ingress Controller** | NGINX Ingress | NGINX | NGINX | NGINX or ALB | NGINX or GCE |
| **Load Balancer** | Service type | MetalLB | Azure LB | AWS NLB/ALB | GCP LB |
| **Storage Class** | `standard` | Longhorn | Azure Disk CSI | EBS CSI | GCE-PD CSI |
| **Secrets Backend** | ESO CRDs | HashiCorp Vault | Azure Key Vault | Secrets Manager | Secret Manager |
| **DNS Provider** | ExternalDNS | Cloudflare | Azure DNS | Route53 | Cloud DNS |
| **Cert Manager** | cert-manager | Let's Encrypt | Let's Encrypt | ACM* | Let's Encrypt |
| **Workload Identity** | ServiceAccount | Vault JWT | Azure AD WI | IRSA | GKE WI |
| **CNI** | - | Cilium/Calico | Azure CNI | VPC CNI | Dataplane V2 |
| **Registry** | GHCR | GHCR/Harbor | ACR | ECR | GAR |

*ACM for AWS-native, cert-manager for portability

---

## Kustomize Structure Pattern

```
clusters/
├── base/                           # Provider-agnostic
│   ├── kustomization.yaml
│   ├── namespaces/
│   │   └── demo-platform.yaml
│   ├── ingress/
│   │   └── nginx-config.yaml       # Generic NGINX config
│   ├── storage/
│   │   └── storageclass.yaml       # Abstract StorageClass
│   └── secrets/
│       └── external-secrets.yaml   # ESO CRDs (no provider)
│
└── overlays/
    ├── kind/                       # Local development
    │   ├── kustomization.yaml
    │   └── patches/
    │       ├── ingress-nodeport.yaml
    │       └── storage-local-path.yaml
    │
    ├── oracle/                     # Oracle Cloud Free Tier
    │   ├── kustomization.yaml
    │   └── patches/
    │       ├── metallb-config.yaml
    │       ├── longhorn-storage.yaml
    │       └── vault-secretstore.yaml
    │
    ├── azure/                      # Azure AKS
    │   ├── kustomization.yaml
    │   └── patches/
    │       ├── azure-disk-storage.yaml
    │       ├── keyvault-secretstore.yaml
    │       └── azure-dns-external.yaml
    │
    ├── aws/                        # AWS EKS
    │   ├── kustomization.yaml
    │   └── patches/
    │       ├── ebs-storage.yaml
    │       ├── secretsmanager-store.yaml
    │       └── route53-external.yaml
    │
    └── gcp/                        # GCP GKE
        ├── kustomization.yaml
        └── patches/
            ├── gce-pd-storage.yaml
            ├── secretmanager-store.yaml
            └── clouddns-external.yaml
```

---

## Terraform Module Structure

```
infra/terraform/
├── modules/
│   ├── cluster/
│   │   ├── main.tf           # Generic cluster interface
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── providers/
│   │       ├── aks.tf        # Azure implementation
│   │       ├── eks.tf        # AWS implementation
│   │       ├── gke.tf        # GCP implementation
│   │       └── oci.tf        # Oracle implementation
│   │
│   ├── network/
│   │   ├── main.tf
│   │   └── providers/
│   │       ├── azure-vnet.tf
│   │       ├── aws-vpc.tf
│   │       ├── gcp-vpc.tf
│   │       └── oci-vcn.tf
│   │
│   └── dns/
│       ├── main.tf
│       └── providers/
│           ├── azure-dns.tf
│           ├── route53.tf
│           ├── clouddns.tf
│           └── cloudflare.tf
│
└── envs/
    ├── oracle-free/
    │   ├── main.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    ├── azure-dev/
    ├── azure-prod/
    ├── aws-dev/
    └── gcp-dev/
```

---

## Provider-Specific Gotchas

### Oracle Cloud Free Tier

```yaml
# CRITICAL: All images MUST support ARM64
image:
  # Use multi-arch images or build for linux/arm64
  repository: ghcr.io/your-org/app
  tag: v1.0.0@sha256:...  # Always pin by digest

# Resources are limited (24 GB RAM total, 4 OCPUs)
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

- **No managed K8s** - use kubeadm
- **No cloud LoadBalancer** - use MetalLB
- **ARM64 only** - verify image compatibility
- **200 GB storage** - use Longhorn for dynamic provisioning

### Azure AKS

```hcl
# Enable workload identity
resource "azurerm_kubernetes_cluster" "main" {
  workload_identity_enabled = true
  oidc_issuer_enabled       = true
}
```

- **Azure CNI** recommended for production
- **Managed identity** for cluster operations
- **Key Vault CSI driver** for secrets
- **Azure Disk** for persistent storage

### AWS EKS

```hcl
# IRSA for workload identity
module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
}
```

- **VPC CNI** with custom networking for large clusters
- **IRSA** for pod-level IAM
- **EBS CSI driver** (not installed by default!)
- **ALB Ingress Controller** as alternative to NGINX

### GCP GKE

```hcl
resource "google_container_cluster" "main" {
  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }
}
```

- **Autopilot** for hands-off management
- **Dataplane V2** (Cilium-based) for networking
- **Workload Identity** for GCP API access
- **GKE Ingress** as native option

---

## Migration Checklist

When migrating between providers:

1. **Images**
   - [ ] Verify multi-arch support (amd64 + arm64)
   - [ ] Update registry references in overlays
   - [ ] Ensure image pull secrets configured

2. **Storage**
   - [ ] Backup all PVCs before migration
   - [ ] Create StorageClass for target provider
   - [ ] Update PVC annotations if needed

3. **Secrets**
   - [ ] Configure ESO SecretStore for new provider
   - [ ] Migrate secrets to new backend
   - [ ] Update ExternalSecret resources

4. **Networking**
   - [ ] Configure LoadBalancer (MetalLB vs Cloud LB)
   - [ ] Update DNS records
   - [ ] Verify Ingress configuration

5. **Identity**
   - [ ] Configure workload identity for new provider
   - [ ] Update ServiceAccount annotations
   - [ ] Verify RBAC permissions

---

## Best Practices

### DO:
- Keep base manifests provider-agnostic
- Use Kustomize patches for provider-specific config
- Abstract storage with named StorageClasses
- Use External Secrets Operator for all secrets
- Build multi-arch container images
- Pin images by digest, not tag
- Document provider-specific requirements

### DON'T:
- Hardcode provider-specific annotations in base
- Use provider-specific storage classes in base
- Assume cloud LoadBalancer availability
- Use provider-native secret stores directly
- Build images for single architecture only
- Use `latest` tags anywhere

---

## Related References

- [references/provider-abstraction.md](references/provider-abstraction.md) - Detailed abstraction patterns
- [references/oracle-cloud.md](references/oracle-cloud.md) - Oracle Free Tier specifics
- [references/azure-aks.md](references/azure-aks.md) - Azure AKS patterns
- [references/aws-eks.md](references/aws-eks.md) - AWS EKS patterns
- [references/gcp-gke.md](references/gcp-gke.md) - GCP GKE patterns
