# Oracle Cloud Free Tier - Kubernetes Reference

## Overview

Oracle Cloud Infrastructure (OCI) Free Tier provides **always-free** resources suitable for MVP/hobby Kubernetes clusters.

## Free Tier Resources

| Resource | Specification |
|----------|---------------|
| Compute | 2x VM.Standard.A1.Flex (ARM) - 4 OCPUs, 24 GB RAM total |
| Storage | 200 GB Block Volume |
| Network | 10 TB/month outbound |
| Load Balancer | 1 flexible LB (10 Mbps) |
| Object Storage | 20 GB |

## Recommended Architecture

```
┌─────────────────────────────────────────┐
│            Oracle Cloud VCN             │
│  ┌─────────────────┐ ┌───────────────┐  │
│  │ Control Plane   │ │ Worker Node   │  │
│  │ (VM.A1.Flex)    │ │ (VM.A1.Flex)  │  │
│  │ 2 OCPUs, 12 GB  │ │ 2 OCPUs, 12 GB│  │
│  │                 │ │               │  │
│  │ - etcd          │ │ - Workloads   │  │
│  │ - API Server    │ │ - Ingress     │  │
│  │ - Controller    │ │ - Storage     │  │
│  │ - Scheduler     │ │               │  │
│  └─────────────────┘ └───────────────┘  │
│           ↓                  ↓          │
│        MetalLB (L2)    Longhorn CSI     │
└─────────────────────────────────────────┘
```

## Critical Requirements

### 1. ARM64 Images Only

All container images MUST support `linux/arm64`:

```bash
# Build multi-arch images
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/org/app:v1.0.0 --push .

# Verify image architecture
docker manifest inspect ghcr.io/org/app:v1.0.0
```

**Common ARM64-compatible images:**
- `nginx:alpine`
- `postgres:16-alpine`
- `redis:7-alpine`
- `bitnami/*` (most charts)
- `grafana/*`
- `prom/*`

**May NOT support ARM64:**
- Some older operator images
- Windows-based images
- Some commercial software

### 2. No Managed Kubernetes

Use kubeadm for cluster setup:

```bash
# On control plane
kubeadm init --pod-network-cidr=10.244.0.0/16

# On worker
kubeadm join <control-plane>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

### 3. MetalLB for LoadBalancer

No cloud LoadBalancer - use MetalLB in L2 mode:

```yaml
# metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.0.1.240-10.0.1.250  # Private subnet range
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
```

### 4. Longhorn for Storage

Install Longhorn for dynamic PV provisioning:

```bash
helm repo add longhorn https://charts.longhorn.io
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath=/var/lib/longhorn
```

StorageClass:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  numberOfReplicas: "2"
  staleReplicaTimeout: "30"
```

### 5. Vault for Secrets

No native secret manager - use HashiCorp Vault:

```yaml
# External Secrets SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "demo-app"
```

## Terraform Setup

```hcl
# Oracle Provider
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

# Free Tier Compute
resource "oci_core_instance" "k8s_node" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type = "image"
    source_id   = var.arm64_image_ocid  # Oracle Linux 8 ARM
  }
}

# Block Volume (200 GB free)
resource "oci_core_volume" "data" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  size_in_gbs         = 100
  vpus_per_gb         = 10  # Balanced performance
}
```

## Network Configuration

```hcl
# VCN
resource "oci_core_vcn" "k8s" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "k8s-vcn"
  dns_label      = "k8s"
}

# Public Subnet (for Ingress)
resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s.id
  cidr_block     = "10.0.0.0/24"
  display_name   = "public"

  security_list_ids = [oci_core_security_list.public.id]
}

# Security List
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.k8s.id

  # Allow HTTP/HTTPS
  ingress_security_rules {
    protocol = "6"  # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Allow K8s API
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
}
```

## Resource Limits

With 24 GB RAM total, budget carefully:

| Component | Memory Request | Memory Limit |
|-----------|----------------|--------------|
| System (kubelet, etc.) | 2 GB | - |
| Argo CD | 512 Mi | 1 Gi |
| PostgreSQL | 256 Mi | 512 Mi |
| Redis | 128 Mi | 256 Mi |
| NGINX Ingress | 128 Mi | 256 Mi |
| Longhorn | 512 Mi | 1 Gi |
| Prometheus | 512 Mi | 1 Gi |
| Grafana | 256 Mi | 512 Mi |
| **Apps Available** | ~16-18 GB | - |

## Limitations

1. **No HA** - Single control plane, no redundancy
2. **No Autoscaling** - Fixed resources
3. **No SLA** - Free tier has no uptime guarantee
4. **ARM64 only** - Limited image compatibility
5. **Performance** - Ampere A1 is good but not top-tier

## Best for

- MVP/PoC environments
- Learning and development
- Cost-conscious hobby projects
- Testing before cloud migration

## Not recommended for

- Production workloads
- High-availability requirements
- x86-only applications
- High-traffic applications
