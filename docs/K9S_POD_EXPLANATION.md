# 🔍 k9s Pod Overview - What Are These 12 Pods?

> **Purpose:** Explanation of all pods running in your kind cluster  
> **Audience:** Developers who want to understand their Kubernetes setup  
> **Last Updated:** 05.10.2025

---

## 📊 Quick Overview

When you run `k9s` and see **12 pods running**, here's what they are:

| Pod | Namespace | Source | Purpose |
|-----|-----------|--------|---------|
| **podinfo** (2x) | tenant-demo | ✅ Your Repo | Your demo application |
| **ingress-nginx-controller** | ingress-nginx | 🔧 Your Script | HTTP routing |
| **coredns** (2x) | kube-system | 🤖 Kubernetes | DNS resolution |
| **etcd** | kube-system | 🤖 Kubernetes | Cluster database |
| **kube-apiserver** | kube-system | 🤖 Kubernetes | API server |
| **kube-controller-manager** | kube-system | 🤖 Kubernetes | Controller brain |
| **kube-proxy** | kube-system | 🤖 Kubernetes | Network proxy |
| **kube-scheduler** | kube-system | 🤖 Kubernetes | Pod scheduler |
| **kindnet** | kube-system | 🤖 kind | Container networking |
| **local-path-provisioner** | local-path-storage | 🤖 kind | Storage provider |

---

## 🎯 Your Application (tenant-demo namespace)

### **podinfo-66d65f586d-5wmz6**
### **podinfo-66d65f586d-tjnln**

**What is it?**
- **Your demo application!** 🎉
- Web server running on port 9898
- Returns JSON with hostname and version
- Demo app by Stefan Prodan (FluxCD maintainer)

**Where does it come from? (Exact source)**
```yaml
# File: apps/podinfo/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2  # Overridden by patch.yaml
  template:
    spec:
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:6.9.2
        ports:
        - containerPort: 9898

# File: apps/podinfo/tenants/demo/patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2  # THIS creates 2 pods!

# Deployed via: kubectl apply -k apps/podinfo/tenants/demo/
# When: During Phase 1 setup (Block 6)
# Script: setup-template/phase1/06-deploy-podinfo/deploy.sh
```

**Why was it built?**
1. **Demo purpose:** Show how Kubernetes deployments work
2. **Learning tool:** Practice with real application (not just hello-world)
3. **Test infrastructure:** Validate Ingress, Service, DNS work correctly
4. **GitOps preparation:** These manifests will be managed by Flux (Phase 2)

**What is it used for?**
- ✅ **Testing HTTP routing:** Access via http://demo.localhost
- ✅ **Monitoring practice:** See logs, metrics, health checks
- ✅ **Scaling demo:** Change replicas and watch k9s
- ✅ **Rolling updates:** Update image version without downtime
- ✅ **Template for your apps:** Copy structure for your own applications

**Is it necessary?**
- ❌ **Not required for cluster:** Kubernetes works without it
- ✅ **Necessary for learning:** Best way to understand how apps run
- ✅ **Necessary for Phase 2:** FluxCD will manage this app automatically
- 🔄 **Replace with your app:** In production, deploy your own application here

**Why 2 pods specifically?**
- **High Availability:** If one crashes, other continues serving
- **Zero Downtime Updates:** Rolling updates (kill pod 1 → wait → kill pod 2)
- **Load Distribution:** Ingress distributes traffic 50/50
- **Realistic Setup:** Production always runs multiple replicas

**How to access?**
```
http://demo.localhost
  ↓
ingress-nginx-controller
  ↓
podinfo Service (Load Balancer)
  ↓
One of the 2 podinfo pods
```

**Test it:**
```bash
# In k9s: Select pod → press 'l' to see logs
# In terminal:
curl http://demo.localhost
# Expected: {"hostname":"podinfo-xxx","version":"6.9.2"}
```

---

## 🌐 HTTP Routing (ingress-nginx namespace)

### **ingress-nginx-controller-9b98df864-twfj**

**What is it?**
- HTTP/HTTPS router for your cluster
- Reads Ingress resources and routes traffic
- Acts as reverse proxy (like nginx/Apache)
- Official nginx-based Ingress controller

**Where does it come from? (Exact source)**
```bash
# Script: setup-template/phase1/05-deploy-ingress/deploy.sh

# Step 1: Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Step 2: Install via Helm Chart
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set controller.service.type=NodePort

# Helm Chart: https://github.com/kubernetes/ingress-nginx
# Version: Latest from official repository
# When: During Phase 1 setup (Block 5)
```

**Why was it built?**
1. **Expose apps externally:** Kubernetes Services are cluster-internal by default
2. **HTTP routing:** Route different domains/paths to different services
3. **kind compatibility:** kind needs special port configuration (hostPort)
4. **Production pattern:** Same setup works in production (with LoadBalancer)

**What is it used for?**
- ✅ **HTTP routing:** `http://demo.localhost` → podinfo service
- ✅ **Path-based routing:** `/api` → backend, `/` → frontend (future)
- ✅ **Virtual hosts:** Multiple domains on same cluster (demo.localhost, api.localhost)
- ✅ **SSL/TLS termination:** HTTPS encryption (Phase 2: cert-manager)
- ✅ **Load balancing:** Distributes traffic across pod replicas

**Is it necessary?**
- ✅ **CRITICAL for HTTP access!** Without it:
  - ❌ `demo.localhost` doesn't work
  - ❌ No external access to pods
  - ❌ Ingress resources don't work
- 🔄 **Alternative:** Use `kubectl port-forward` (only for development)
- 🔄 **Alternative:** Use NodePort services (not production-friendly)
- ✅ **Production standard:** Every cluster needs an Ingress controller

**Why hostPort mode?**
```
Problem: kind runs in Docker, no real LoadBalancer
Solution: hostPort maps container port → host port
Result: localhost:80 → kind container:80 → Ingress Controller

Alternative modes:
- LoadBalancer: Cloud providers only (AWS ELB, Azure LB, GCP LB)
- NodePort: Exposes random high ports (31000-32767)
- hostPort: Maps to standard ports (80, 443) ✅ Best for kind!
```

**Check it:**
```bash
# In k9s: :ing (shows Ingress rules)
# In terminal:
kubectl get ingress -n tenant-demo
# Expected: demo.localhost → podinfo:9898
```

---

## 🧠 Kubernetes Control Plane (kube-system namespace)

### **kube-apiserver-agent-k8s-local-control-plane**

**What is it?**
- **The heart of Kubernetes!** ❤️
- REST API server for all cluster operations
- ALL kubectl commands go through this
- Validates, authenticates, authorizes all requests

**Where does it come from? (Exact source)**
```bash
# Automatically created by kind during cluster creation:
kind create cluster --config kind-config.yaml

# kind downloads and runs:
# Image: kindest/node:v1.27.3 (contains kube-apiserver binary)
# Binary: /usr/local/bin/kube-apiserver
# Config: /etc/kubernetes/manifests/kube-apiserver.yaml (Static Pod)

# When: During Phase 1 setup (Block 4 - Create Cluster)
# Script: setup-template/phase1/04-create-cluster/create.sh
```

**Why was it built?**
1. **Central API gateway:** Every Kubernetes operation needs one entry point
2. **Security:** Authentication, authorization, admission control
3. **Validation:** Ensures manifests are valid before applying
4. **State management:** Coordinates with etcd (database)
5. **Watch mechanism:** Clients can watch for resource changes

**What is it used for?**
- ✅ **kubectl commands:** `kubectl get/apply/delete/logs/exec` ALL go here
- ✅ **k9s UI:** k9s talks to API server for all data
- ✅ **Internal controllers:** Controller-Manager, Scheduler query API server
- ✅ **Webhooks:** Ingress, Admission controllers call API server
- ✅ **REST API:** `curl https://localhost:6443/api/v1/pods` (with auth)

**Is it necessary?**
- ✅ **ABSOLUTELY CRITICAL!** Without it:
  - ❌ No kubectl (can't manage cluster)
  - ❌ No k9s (can't see cluster state)
  - ❌ No controllers (nothing automated)
  - ❌ Cluster is completely dead
- 🔒 **Single Point of Failure:** If API server crashes, cluster is unusable
- 🔄 **High Availability:** Production runs 3+ API servers behind load balancer

**What does it do exactly?**
```
kubectl get pods
  ↓
1. Authentication: Check user identity (certificate, token)
  ↓
2. Authorization: Check user permissions (RBAC rules)
  ↓
3. Admission Control: Run validation plugins
  ↓
4. Query etcd: Read pod data from database
  ↓
5. Return JSON: Send pod list back to kubectl

kubectl apply -f deployment.yaml
  ↓
1-3. Auth + Authorization + Admission (same as above)
  ↓
4. Validation: Check YAML syntax, required fields
  ↓
5. Write to etcd: Save deployment definition
  ↓
6. Notify watchers: Controller-Manager sees new deployment
  ↓
7. Return success: kubectl shows "deployment created"
```

**Port exposure:**
```
Internal: 6443 (HTTPS, requires certificate)
Access: kubectl, k9s, controllers (all use this port)
```

---

### **kube-controller-manager-agent-k8s-local-control-plane**

**What is it?**
- **The brain of Kubernetes!** 🧠
- Monitors cluster state and takes action
- Ensures "desired state = actual state"

**Where does it come from?**
- Automatically created by kind
- Core Kubernetes component

**What does it do?**
```
Your deployment.yaml says: replicas: 2
Current state: Only 1 pod running
  ↓
Controller-Manager detects difference
  ↓
Creates 2nd pod to match desired state

Pod crashes
  ↓
Controller-Manager detects missing pod
  ↓
Creates new pod automatically
```

**Examples of controllers:**
- **Deployment Controller:** Manages ReplicaSets
- **ReplicaSet Controller:** Ensures N pods are running
- **Service Controller:** Creates ClusterIP endpoints
- **Node Controller:** Monitors node health

---

### **kube-scheduler-agent-k8s-local-control-plane**

**What is it?**
- **Resource matchmaker** 📍
- Decides which node should run each pod
- Considers: CPU, RAM, affinity, taints

**Where does it come from?**
- Automatically created by kind
- Core Kubernetes component

**What does it do?**
```
New pod created (by Controller-Manager)
  ↓
Scheduler checks:
  - Which nodes have enough CPU?
  - Which nodes have enough RAM?
  - Any affinity rules?
  - Any taints/tolerations?
  ↓
Selects best node
  ↓
Pod is scheduled to node
```

**In your case:**
- Only 1 node (kind cluster)
- Scheduler assigns all pods to: `agent-k8s-local-control-plane`

---

### **etcd-agent-k8s-local-control-plane**

**What is it?**
- **Cluster database** 💾
- Stores ALL cluster data (configs, secrets, state)
- Distributed key-value store

**Where does it come from?**
- Automatically created by kind
- Core Kubernetes component

**What does it store?**
```
/registry/pods/tenant-demo/podinfo-xxx        → Pod definition
/registry/services/tenant-demo/podinfo        → Service definition
/registry/deployments/tenant-demo/podinfo     → Deployment definition
/registry/secrets/...                         → Secrets (encrypted)
/registry/configmaps/...                      → ConfigMaps
```

**Comparison:**
- Like MySQL/PostgreSQL for your app
- etcd = Kubernetes' database
- If etcd crashes → Cluster loses all data! 💥

**How to query it:**
```bash
# Don't query etcd directly! Use kubectl:
kubectl get all -A
# kubectl reads from etcd via kube-apiserver
```

---

### **kube-proxy-7hq59**

**What is it?**
- **Network proxy** 🌐
- Implements Kubernetes Services (ClusterIP, NodePort)
- Routes traffic to pods

**Where does it come from?**
- Automatically created by kind
- Runs as DaemonSet (one per node)

**What does it do?**
```
Service: podinfo (ClusterIP 10.96.253.107:9898)
  ↓
kube-proxy updates iptables rules:
  "Traffic to 10.96.253.107:9898 → Load balance to Pod IPs"
  ↓
Traffic arrives at 10.96.253.107:9898
  ↓
kube-proxy routes to: 10.244.0.8:9898 or 10.244.0.9:9898
```

**Modes:**
- **iptables mode** (default): Fast, kernel-level routing
- **IPVS mode**: Even faster, advanced load balancing
- **userspace mode**: Old, slow (legacy)

---

### **coredns-5d78c9869d-gq271**
### **coredns-5d78c9869d-vnzvn**

**What is it?**
- **DNS server for your cluster** 🌍
- Resolves service names to IPs
- Like `/etc/hosts` but dynamic
- Replaces legacy kube-dns

**Where does it come from? (Exact source)**
```bash
# Automatically deployed by Kubernetes during cluster init

# Deployment: kubernetes/cluster/addons/dns/coredns/coredns.yaml.base
# Image: registry.k8s.io/coredns/coredns:v1.10.1
# Config: CoreDNS Corefile (ConfigMap)

# When: Automatically during kind cluster creation
# Script: kind create cluster (triggers Kubernetes default addons)
```

**Why was it built?**
1. **Service discovery:** Pods need to find services by name, not IP
2. **Dynamic DNS:** IPs change when pods restart, names stay stable
3. **Cross-namespace:** Pods can discover services in other namespaces
4. **External DNS:** Forward external queries (google.com, github.com)
5. **Kubernetes-aware:** Watches Services/Endpoints, updates DNS automatically

**What is it used for?**
- ✅ **Service resolution:** `podinfo` → `10.96.253.107`
- ✅ **FQDN resolution:** `podinfo.tenant-demo.svc.cluster.local` → IP
- ✅ **Pod DNS:** Each pod gets DNS name: `pod-ip.namespace.pod.cluster.local`
- ✅ **External queries:** `curl https://google.com` (forwarded to 8.8.8.8)
- ✅ **Search domains:** Pod's `/etc/resolv.conf` has search paths

**Is it necessary?**
- ✅ **CRITICAL for service discovery!** Without it:
  - ❌ Pods can't find services by name
  - ❌ Must hardcode IPs (breaks when pods restart)
  - ❌ No cross-namespace communication
  - ❌ Ingress-nginx can't resolve `podinfo.tenant-demo`
- 🔄 **Alternative:** kube-dns (older, deprecated)
- 🔄 **Alternative:** External DNS (not Kubernetes-aware)

**DNS naming format:**
```
<service>.<namespace>.svc.cluster.local
  ↓
podinfo.tenant-demo.svc.cluster.local → 10.96.253.107

Short forms also work:
- podinfo (same namespace as client pod)
- podinfo.tenant-demo (from other namespace)
- podinfo.tenant-demo.svc (explicit service)
- podinfo.tenant-demo.svc.cluster.local (FQDN)

Pod DNS:
10-244-0-8.tenant-demo.pod.cluster.local → 10.244.0.8
```

**Why 2 CoreDNS pods?**
- **High Availability:** If one crashes, other continues serving
- **Load Balancing:** DNS queries distributed across both
- **Performance:** Multiple pods handle high query volume
- **Production standard:** Always run ≥2 DNS pods

**How pods use CoreDNS:**
```bash
# Inside a pod:
cat /etc/resolv.conf
# Output:
# nameserver 10.96.0.10  ← CoreDNS Service IP
# search tenant-demo.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5

# This means:
# 1. DNS queries go to 10.96.0.10 (CoreDNS Service)
# 2. Service routes to one of 2 CoreDNS pods
# 3. Short names auto-expanded: "podinfo" → "podinfo.tenant-demo.svc.cluster.local"
```

**CoreDNS configuration:**
```yaml
# ConfigMap: coredns (kube-system namespace)
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    forward . /etc/resolv.conf {
        max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}

# Translation:
# - Listen on port 53 (DNS standard)
# - Resolve *.cluster.local (Kubernetes services)
# - Forward external queries (google.com) to /etc/resolv.conf
# - Cache results for 30 seconds
# - Load balance across pods
```

**Test it:**
```bash
# From inside a pod:
kubectl exec -n tenant-demo podinfo-xxx -- nslookup podinfo
# Expected: Name: podinfo, Address: 10.96.253.107
```

---

### **kindnet-knxcx**

**What is it?**
- **Container Network Interface (CNI) plugin** 🔌
- Connects pods across the cluster
- Assigns IP addresses to pods

**Where does it come from?**
- Automatically created by kind
- kind's default networking solution

**What does it do?**
```
Pod A (10.244.0.8) wants to connect to Pod B (10.244.0.9)
  ↓
kindnet creates network routes
  ↓
Pods can communicate via internal IPs
```

**Alternatives (in production):**
- **Calico**: Advanced networking + policies
- **Flannel**: Simple overlay network
- **Cilium**: eBPF-based, very fast
- **Weave**: Easy multi-cluster networking

**In your setup:**
- Only 1 node → Simple networking
- Pods share same network namespace
- No need for complex routing

---

## 💾 Storage (local-path-storage namespace)

### **local-path-provisioner-6bc4bddd6b-mc8fj**

**What is it?**
- **Dynamic storage provisioner** 📦
- Creates volumes on local disk
- Implements PersistentVolumes

**Where does it come from?**
- Automatically created by kind
- kind's default StorageClass

**What does it do?**
```
App requests: PersistentVolumeClaim (10GB)
  ↓
local-path-provisioner sees request
  ↓
Creates directory: /tmp/hostpath-provisioner/pvc-xxx
  ↓
Mounts as volume in pod
```

**Example usage:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-storage
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard  # Uses local-path-provisioner
```

**In production:**
- Use real storage: AWS EBS, Azure Disk, GCE PD
- Network storage: NFS, Ceph, GlusterFS
- Cloud storage: S3, Azure Blob

---

## 📊 Summary Table

### **Pods from YOUR repository (2):**

| Pod | Namespace | File | Necessary? | Can Delete? |
|-----|-----------|------|------------|-------------|
| podinfo (2x) | tenant-demo | `apps/podinfo/base/deployment.yaml` | ❌ Demo only | ✅ Yes (cluster works without) |

**Purpose:** Demo application for learning. Replace with your own apps in production.

---

### **Pods from YOUR scripts (1):**

| Pod | Namespace | Script | Necessary? | Can Delete? |
|-----|-----------|--------|------------|-------------|
| ingress-nginx-controller | ingress-nginx | `setup-template/phase1/05-deploy-ingress/deploy.sh` | ✅ For HTTP access | ⚠️ Only if using port-forward |

**Purpose:** Expose apps via HTTP. REQUIRED for `demo.localhost` to work!

---

### **Pods from Kubernetes/kind (9):**

| Pod | Namespace | Type | Necessary? | Can Delete? |
|-----|-----------|------|------------|-------------|
| coredns (2x) | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (breaks DNS) |
| etcd | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (cluster dies) |
| kube-apiserver | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (kubectl stops) |
| kube-controller-manager | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (no automation) |
| kube-proxy | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (networking breaks) |
| kube-scheduler | kube-system | Kubernetes Core | ✅ CRITICAL | ❌ No! (pods won't schedule) |
| kindnet | kube-system | kind Networking | ✅ CRITICAL | ❌ No! (pods can't communicate) |
| local-path-provisioner | local-path-storage | kind Storage | ⚠️ If using PVCs | ✅ Yes (if no volumes needed) |

**Purpose:** Core Kubernetes infrastructure. **DO NOT DELETE** these pods!

---

## 🎯 Which Pods Can I Safely Delete?

### **✅ Safe to delete (Demo/Optional):**

```bash
# Delete podinfo (demo app)
kubectl delete namespace tenant-demo
# Impact: demo.localhost stops working
# Recovery: kubectl apply -k apps/podinfo/tenants/demo/

# Delete Ingress (if not using HTTP access)
kubectl delete namespace ingress-nginx
# Impact: demo.localhost stops working, use port-forward instead
# Recovery: ./setup-template/phase1/05-deploy-ingress/deploy.sh

# Delete local-path-provisioner (if not using storage)
kubectl delete namespace local-path-storage
# Impact: Can't create PersistentVolumes
# Recovery: Reinstall kind cluster
```

### **❌ NEVER delete (Cluster dies):**

```bash
# These will BREAK your cluster:
kubectl delete pod -n kube-system etcd-xxx                    # ← Cluster loses ALL data
kubectl delete pod -n kube-system kube-apiserver-xxx          # ← kubectl stops working
kubectl delete pod -n kube-system kube-controller-manager-xxx # ← No automation
kubectl delete pod -n kube-system kube-scheduler-xxx          # ← Pods won't start
kubectl delete pod -n kube-system kube-proxy-xxx              # ← Networking breaks
kubectl delete pod -n kube-system coredns-xxx                 # ← DNS breaks
kubectl delete pod -n kube-system kindnet-xxx                 # ← Pod communication breaks
```

**Note:** These are Static Pods (managed by kubelet). They auto-restart if deleted, but causes brief downtime.

---

## 🔍 Dependency Map

```
Your Application (podinfo)
  ↓ depends on
Ingress Controller (ingress-nginx)
  ↓ depends on
CoreDNS (service discovery)
  ↓ depends on
kube-proxy (networking)
  ↓ depends on
kindnet (CNI)
  ↓ depends on
kube-scheduler (pod placement)
  ↓ depends on
kube-controller-manager (automation)
  ↓ depends on
kube-apiserver (API)
  ↓ depends on
etcd (database)

Bottom line: etcd & kube-apiserver are THE MOST CRITICAL!
```

---

## 📈 Resource Usage (Typical)

| Pod | CPU | Memory | Criticality |
|-----|-----|--------|-------------|
| podinfo | 10m | 64Mi | Low (demo) |
| ingress-nginx | 50m | 128Mi | High (for HTTP) |
| coredns | 10m | 32Mi | **CRITICAL** |
| etcd | 100m | 256Mi | **CRITICAL** |
| kube-apiserver | 200m | 512Mi | **CRITICAL** |
| kube-controller-manager | 100m | 256Mi | **CRITICAL** |
| kube-scheduler | 50m | 128Mi | **CRITICAL** |
| kube-proxy | 10m | 32Mi | **CRITICAL** |
| kindnet | 10m | 32Mi | **CRITICAL** |
| local-path-provisioner | 10m | 32Mi | Optional |

**Total:** ~560m CPU, ~1.5GB RAM (for entire cluster!)

---

## 🎓 Production vs. Development Differences

### **Development (kind - what you have):**
- ✅ Single node (all pods on one machine)
- ✅ hostPort for Ingress (port 80/443)
- ✅ local-path-provisioner (disk volumes)
- ✅ Single replica for system pods

### **Production (AKS/EKS/GKE - Phase 2):**
- 🚀 Multiple nodes (3-5+ worker nodes)
- 🚀 LoadBalancer for Ingress (cloud provider)
- 🚀 Cloud storage (Azure Disk, AWS EBS, GCP PD)
- 🚀 Multiple replicas for everything (HA)
- 🚀 Resource limits enforced
- 🚀 Monitoring (Prometheus, Grafana)
- 🚀 Logging (Loki, Elasticsearch)
- 🚀 GitOps (Flux auto-deploys from Git)

---

## 🎓 Learning Resources

### **Understand Kubernetes Components:**
- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- [Control Plane Components](https://kubernetes.io/docs/concepts/overview/components/#control-plane-components)
- [Node Components](https://kubernetes.io/docs/concepts/overview/components/#node-components)

### **Explore your cluster with k9s:**
```bash
# Start k9s
k9s

# Navigation:
:pods          → Show all pods
:svc           → Show services
:ing           → Show ingresses
:deploy        → Show deployments
:ns            → Show namespaces

# Actions (select pod first):
l              → View logs
d              → Describe resource
e              → Edit YAML
Ctrl+k         → Delete resource

# Filters:
/podinfo       → Filter by name
Ctrl+a         → Show all namespaces

# Help:
?              → Show all shortcuts
:q             → Quit
```

### **Kubernetes Architecture:**
```
┌─────────────────────────────────────────────────────┐
│ Control Plane (Master)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ API Server   │  │ Scheduler    │  │ etcd     │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│  ┌──────────────────────────────────────────────┐  │
│  │ Controller-Manager                            │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Node (Worker)                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ kubelet      │  │ kube-proxy   │  │ CNI      │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│  ┌──────────────────────────────────────────────┐  │
│  │ Pods (Your Applications)                      │  │
│  │  - podinfo                                    │  │
│  │  - ingress-nginx                              │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 🔍 Quick Debugging Commands

### **Check pod status:**
```bash
kubectl get pods -A
kubectl describe pod -n tenant-demo podinfo-xxx
kubectl logs -n tenant-demo podinfo-xxx
```

### **Check services:**
```bash
kubectl get svc -A
kubectl describe svc -n tenant-demo podinfo
kubectl get endpoints -n tenant-demo podinfo
```

### **Check ingress:**
```bash
kubectl get ingress -A
kubectl describe ingress -n tenant-demo podinfo
```

### **Check cluster health:**
```bash
kubectl get nodes
kubectl get componentstatuses  # Deprecated in newer versions
kubectl cluster-info
```

### **Use k9s for visual overview:**
```bash
k9s
# Press Ctrl+a to see all namespaces
# Press :pods to see all pods
# Select pod → press 'l' for logs
# Select pod → press 'd' for description
```

---

## ✅ Health Check

**All 12 pods should show:**
- ✅ STATUS: Running
- ✅ READY: 1/1 (or 2/2 if multi-container)
- ✅ RESTARTS: 0 (or low number)
- ✅ AGE: Similar age (created at cluster start)

**If any pod shows:**
- ❌ CrashLoopBackOff → Check logs: `kubectl logs <pod>`
- ❌ ImagePullBackOff → Check image name/registry
- ❌ Pending → Check resources: `kubectl describe pod <pod>`
- ❌ Error → Check logs and events

---

**Last Updated:** 05.10.2025  
**Your Cluster:** agent-k8s-local (kind v0.20.0, K8s v1.27.3)  
**Total Pods:** 12 (2 from your repo, 1 from scripts, 9 from Kubernetes/kind)  
**Status:** ✅ All Running
