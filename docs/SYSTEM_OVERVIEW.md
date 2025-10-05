# 🔍 System Overview - How Everything Works

> **Purpose:** Understand your Kubernetes setup, how to manage it, and see what's happening  
> **Audience:** Developers who want to understand their local K8s environment  
> **Last Updated:** 05.10.2025

---

## 📊 Table of Contents

1. [Architecture Overview](#-architecture-overview)
2. [How to See What's Running](#-how-to-see-whats-running)
3. [How Requests Flow Through the System](#-how-requests-flow-through-the-system)
4. [How to Manage Resources](#-how-to-manage-resources)
5. [How Manifests Control Everything](#-how-manifests-control-everything)
6. [Troubleshooting & Debugging](#-troubleshooting--debugging)
7. [Advanced Operations](#-advanced-operations)

---

## 🏗️ Architecture Overview

### **Your Current Setup:**

```
┌─────────────────────────────────────────────────────────────┐
│  Your Machine (Ubuntu)                                       │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Docker Daemon                                          │ │
│  │                                                          │ │
│  │  ┌─────────────────────────────────────────────────┐   │ │
│  │  │  kind Cluster (agent-k8s-local)                  │   │ │
│  │  │                                                   │   │ │
│  │  │  ┌─────────────────────────────────────────┐    │   │ │
│  │  │  │  Namespace: kube-system                  │    │   │ │
│  │  │  │  - coredns (DNS)                         │    │   │ │
│  │  │  │  - kube-apiserver (API)                  │    │   │ │
│  │  │  │  - etcd (Database)                       │    │   │ │
│  │  │  │  - kube-controller-manager               │    │   │ │
│  │  │  │  - kube-scheduler                        │    │   │ │
│  │  │  └─────────────────────────────────────────┘    │   │ │
│  │  │                                                   │   │ │
│  │  │  ┌─────────────────────────────────────────┐    │   │ │
│  │  │  │  Namespace: ingress-nginx                │    │   │ │
│  │  │  │  - ingress-nginx-controller              │    │   │ │
│  │  │  │    (Routes HTTP traffic)                 │    │   │ │
│  │  │  │    Ports: 80 → 31795, 443 → 30633       │    │   │ │
│  │  │  └─────────────────────────────────────────┘    │   │ │
│  │  │                                                   │   │ │
│  │  │  ┌─────────────────────────────────────────┐    │   │ │
│  │  │  │  Namespace: tenant-demo                  │    │   │ │
│  │  │  │  - podinfo-xxx (Pod 1)                   │    │   │ │
│  │  │  │  - podinfo-yyy (Pod 2)                   │    │   │ │
│  │  │  │  - podinfo Service (ClusterIP)           │    │   │ │
│  │  │  │  - podinfo Ingress (demo.localhost)      │    │   │ │
│  │  │  └─────────────────────────────────────────┘    │   │ │
│  │  └─────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  Browser: http://demo.localhost                           │
│           ↓                                               │
│  Ingress Controller: Ports 80/443 → Pod IPs              │
└─────────────────────────────────────────────────────────────┘
```

### **Key Components Explained:**

#### **1. kind (Kubernetes in Docker)**
- **What:** Creates a Kubernetes cluster using Docker containers
- **Where:** Docker container named `agent-k8s-local-control-plane`
- **Why:** Fast local development without heavy VMs

```bash
# See the Docker container
docker ps

# Expected output:
# CONTAINER ID   IMAGE                  COMMAND                  PORTS
# xxxxx          kindest/node:v1.27.3   "/usr/local/bin/entr…"   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

#### **2. Namespaces (Logical Separation)**
- **kube-system:** Kubernetes core services (you don't touch)
- **ingress-nginx:** HTTP routing layer (manages external access)
- **tenant-demo:** Your application (podinfo demo)

```bash
# List all namespaces
kubectl get namespaces

# See what's in each namespace
kubectl get all -n kube-system
kubectl get all -n ingress-nginx
kubectl get all -n tenant-demo
```

#### **3. Pods (Running Containers)**
- **What:** Smallest unit in Kubernetes, contains 1+ containers
- **podinfo pods:** Run your application (2 replicas for redundancy)
- **Ephemeral:** Pods can be deleted/recreated, data is lost

```bash
# See all pods
kubectl get pods -A

# See details of one pod
kubectl describe pod -n tenant-demo podinfo-xxx
```

#### **4. Services (Internal Load Balancer)**
- **What:** Stable IP address for accessing pods
- **podinfo service:** ClusterIP 10.96.253.107 → Routes to both pods
- **Why:** Pods have changing IPs, Service stays stable

```bash
# See services
kubectl get svc -A

# See which pods the service targets
kubectl get endpoints -n tenant-demo podinfo
```

#### **5. Ingress (External Access)**
- **What:** HTTP routing from outside → inside cluster
- **podinfo ingress:** demo.localhost → podinfo service → pods
- **How:** nginx-ingress-controller reads Ingress rules

```bash
# See ingress rules
kubectl get ingress -A

# See ingress details
kubectl describe ingress -n tenant-demo podinfo
```

---

## 👁️ How to See What's Running

### **Dashboard: View Everything at Once**

```bash
# Terminal UI (recommended for beginners)
# Install k9s:
curl -sS https://webinstall.dev/k9s | bash
source ~/.config/envman/PATH.env

# Start k9s
k9s

# Navigation:
# :pods          → All pods
# :svc           → Services
# :ing           → Ingresses
# :deploy        → Deployments
# :ns            → Namespaces
# /              → Search
# l              → Show logs (select a pod first)
# d              → Describe resource
# e              → Edit resource
# Ctrl+C         → Exit
```

### **Command Line: Specific Queries**

#### **See All Resources**
```bash
# Everything in all namespaces
kubectl get all -A

# Everything in one namespace
kubectl get all -n tenant-demo
```

#### **See Pods (Running Containers)**
```bash
# All pods
kubectl get pods -A

# Pods with more details (IP, Node, Status)
kubectl get pods -n tenant-demo -o wide

# Watch pods in real-time
kubectl get pods -n tenant-demo -w

# Pod details (events, conditions, volumes)
kubectl describe pod -n tenant-demo podinfo-xxx
```

#### **See Services (Networking)**
```bash
# All services
kubectl get svc -A

# Service details (endpoints, selector)
kubectl describe svc -n tenant-demo podinfo

# Which pods does this service target?
kubectl get endpoints -n tenant-demo podinfo
```

#### **See Ingress (HTTP Routing)**
```bash
# All ingress rules
kubectl get ingress -A

# Ingress details (rules, backends)
kubectl describe ingress -n tenant-demo podinfo

# Test if ingress is working
curl -I http://demo.localhost
```

#### **See Deployments (Pod Controllers)**
```bash
# All deployments
kubectl get deployments -A

# Deployment details (replicas, strategy, conditions)
kubectl describe deployment -n tenant-demo podinfo

# Deployment history (rollout revisions)
kubectl rollout history deployment -n tenant-demo podinfo
```

#### **See Events (What Happened)**
```bash
# Recent events in all namespaces
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Events in one namespace
kubectl get events -n tenant-demo --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n tenant-demo -w
```

#### **See Logs (Application Output)**
```bash
# Logs from one pod
kubectl logs -n tenant-demo podinfo-xxx

# Logs from all podinfo pods
kubectl logs -n tenant-demo -l app=podinfo --tail=50

# Follow logs in real-time
kubectl logs -n tenant-demo -l app=podinfo -f

# Previous container logs (if pod crashed)
kubectl logs -n tenant-demo podinfo-xxx --previous
```

#### **See Resource Usage (CPU, Memory)**
```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n tenant-demo

# If "metrics-server not found":
# Install metrics-server first:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

---

## 🔄 How Requests Flow Through the System

### **HTTP Request: Browser → podinfo**

```
1. Browser:           http://demo.localhost
                      ↓
2. /etc/hosts:        127.0.0.1 demo.localhost
                      ↓
3. Localhost:80       → Docker port mapping → kind container
                      ↓
4. kind hostPort:80   → ingress-nginx-controller pod
                      ↓
5. Ingress Rule:      Host: demo.localhost → Service: podinfo
                      ↓
6. Service:           ClusterIP 10.96.253.107:9898
                      ↓
7. Endpoints:         Pod IPs (10.244.0.x:9898, 10.244.0.y:9898)
                      ↓
8. Pod:               podinfo container responds with JSON
                      ↓
9. Response:          {"hostname":"podinfo-xxx","version":"6.9.2"}
```

### **Verify Each Step:**

#### **Step 1-2: DNS Resolution**
```bash
# Check /etc/hosts
grep demo.localhost /etc/hosts
# Expected: 127.0.0.1 demo.localhost

# Test DNS
ping demo.localhost -c 1
# Expected: 64 bytes from 127.0.0.1
```

#### **Step 3-4: Docker Port Mapping**
```bash
# Check kind container ports
docker ps --filter name=agent-k8s-local
# Expected: 0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp

# Check if nginx is listening
docker exec agent-k8s-local-control-plane netstat -tlnp | grep :80
# Expected: :80  LISTEN  (nginx or socat)
```

#### **Step 5: Ingress Rule**
```bash
# Check ingress configuration
kubectl get ingress -n tenant-demo podinfo -o yaml

# Look for:
# spec.rules.host: demo.localhost
# spec.rules.http.paths[0].backend.service.name: podinfo
```

#### **Step 6: Service Routing**
```bash
# Check service
kubectl get svc -n tenant-demo podinfo -o wide
# Expected: ClusterIP 10.96.x.x, PORT(S) 9898/TCP

# Check service selector
kubectl describe svc -n tenant-demo podinfo | grep Selector
# Expected: Selector: app=podinfo
```

#### **Step 7: Endpoints (Pod IPs)**
```bash
# Check endpoints
kubectl get endpoints -n tenant-demo podinfo
# Expected: 10.244.0.x:9898,10.244.0.y:9898

# Verify pod IPs match
kubectl get pods -n tenant-demo -o wide
# Expected: IPs match endpoints
```

#### **Step 8: Pod Response**
```bash
# Direct pod access (bypass service)
kubectl port-forward -n tenant-demo podinfo-xxx 9898:9898 &
curl http://localhost:9898

# Kill port-forward
pkill -f "port-forward.*podinfo"
```

### **Debugging Flow Issues:**

```bash
# If demo.localhost doesn't work:

# 1. Check if ingress controller is running
kubectl get pods -n ingress-nginx
# Must be: Running + Ready 1/1

# 2. Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# 3. Check if service has endpoints
kubectl get endpoints -n tenant-demo podinfo
# Must show pod IPs

# 4. Test pod directly (bypass ingress)
POD=$(kubectl get pod -n tenant-demo -l app=podinfo -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n tenant-demo $POD 9898:9898 &
curl http://localhost:9898
# If this works → Ingress problem
# If this fails → Pod problem

# 5. Check ingress controller configuration
kubectl exec -n ingress-nginx -it $(kubectl get pod -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- cat /etc/nginx/nginx.conf | grep demo.localhost
```

---

## 🛠️ How to Manage Resources

### **1. Scaling (Replicas)**

#### **Scale Up/Down:**
```bash
# Scale deployment to 3 replicas
kubectl scale deployment podinfo -n tenant-demo --replicas=3

# Check result
kubectl get pods -n tenant-demo -w
# Expected: 3 pods after ~10s

# Scale down to 1
kubectl scale deployment podinfo -n tenant-demo --replicas=1
```

#### **Make Scaling Permanent (Edit Manifest):**
```bash
# Edit file
vim ~/agent-ready-k8s/apps/podinfo/tenants/demo/patch.yaml

# Change:
# spec:
#   replicas: 2  →  replicas: 3

# Apply changes
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/

# Commit to Git (for Phase 2 GitOps)
git add apps/podinfo/tenants/demo/patch.yaml
git commit -m "feat: scale podinfo to 3 replicas"
git push
```

### **2. Updating (Change Image/Config)**

#### **Change Image Version:**
```bash
# Update deployment to new version
kubectl set image deployment/podinfo -n tenant-demo podinfo=ghcr.io/stefanprodan/podinfo:6.9.3

# Watch rollout
kubectl rollout status deployment/podinfo -n tenant-demo

# Check version
curl http://demo.localhost | jq '.version'
# Expected: "6.9.3"

# Rollback if needed
kubectl rollout undo deployment/podinfo -n tenant-demo
```

#### **Edit Environment Variables:**
```bash
# Edit deployment directly (temporary)
kubectl edit deployment podinfo -n tenant-demo

# Add in spec.template.spec.containers[0]:
#   env:
#   - name: PODINFO_UI_COLOR
#     value: "#00ff00"  # Green UI

# Apply
# Pods will restart automatically

# Test
curl http://demo.localhost | jq '.color'
# Expected: "#00ff00"
```

#### **Make Changes Permanent:**
```bash
# Edit manifest
vim ~/agent-ready-k8s/apps/podinfo/base/deployment.yaml

# Add in containers[0]:
#   env:
#   - name: PODINFO_UI_COLOR
#     value: "#00ff00"

# Apply
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/

# Commit
git add apps/podinfo/base/deployment.yaml
git commit -m "feat: change podinfo UI color to green"
```

### **3. Restarting (Pods/Deployments)**

#### **Restart All Pods (Rolling Restart):**
```bash
# Restart deployment (pods are recreated)
kubectl rollout restart deployment/podinfo -n tenant-demo

# Watch
kubectl get pods -n tenant-demo -w
# Old pods: Terminating, New pods: Creating → Running

# Why? Sometimes needed for config changes, memory leaks, etc.
```

#### **Delete One Pod (Kubernetes Recreates):**
```bash
# Delete one pod
kubectl delete pod -n tenant-demo podinfo-xxx

# Kubernetes automatically creates new pod
kubectl get pods -n tenant-demo -w
# Expected: New pod appears with different name
```

#### **Restart Entire Namespace:**
```bash
# Delete all pods in namespace (deployments recreate them)
kubectl delete pods --all -n tenant-demo

# Watch recreation
kubectl get pods -n tenant-demo -w
```

### **4. Deleting Resources**

#### **Delete Pod (Recreated by Deployment):**
```bash
kubectl delete pod -n tenant-demo podinfo-xxx
# New pod appears automatically
```

#### **Delete Deployment (Deletes All Pods):**
```bash
kubectl delete deployment podinfo -n tenant-demo
# All podinfo pods are deleted
# Service/Ingress still exist!
```

#### **Delete Everything in Namespace:**
```bash
kubectl delete all --all -n tenant-demo
# Deletes: Pods, Services, Deployments
# Keeps: Namespace, Ingress (not in "all")
```

#### **Delete Namespace (Complete Cleanup):**
```bash
kubectl delete namespace tenant-demo
# Deletes everything inside namespace
# Including: Pods, Services, Deployments, Ingress
```

#### **Recreate After Deletion:**
```bash
# From manifests
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/

# Or from script
~/agent-ready-k8s/setup-template/phase1/06-deploy-podinfo/deploy.sh
```

---

## 📄 How Manifests Control Everything

### **Understanding the Manifest Structure:**

```
apps/podinfo/
├── base/                          ← Base configuration (shared)
│   ├── deployment.yaml            ← Defines: image, replicas, resources
│   ├── service.yaml               ← Defines: port, selector
│   ├── hpa.yaml                   ← (Optional) Auto-scaling rules
│   └── kustomization.yaml         ← Lists base resources
└── tenants/
    └── demo/                      ← Tenant-specific overlay
        ├── kustomization.yaml     ← References base + applies patches
        └── patch.yaml             ← Overrides: replicas, adds ingress
```

### **Key Files Explained:**

#### **1. apps/podinfo/base/deployment.yaml**
**What it does:** Defines HOW podinfo runs

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo              # Deployment name
spec:
  replicas: 2                # How many pods (overridden by patch)
  selector:
    matchLabels:
      app: podinfo           # Which pods to manage
  template:
    metadata:
      labels:
        app: podinfo         # Pod labels
    spec:
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:6.9.2  # Container image
        ports:
        - containerPort: 9898     # App listens on port 9898
        resources:
          requests:
            cpu: 100m              # Minimum CPU
            memory: 64Mi           # Minimum RAM
          limits:
            cpu: 1000m             # Maximum CPU
            memory: 128Mi          # Maximum RAM
```

**Change this to:**
- Update image version
- Change resource limits
- Add environment variables
- Add volume mounts

#### **2. apps/podinfo/base/service.yaml**
**What it does:** Exposes pods internally

```yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo              # Service name
spec:
  type: ClusterIP            # Internal IP (not exposed outside)
  selector:
    app: podinfo             # Targets pods with label app=podinfo
  ports:
  - name: http
    port: 9898               # Service port
    targetPort: 9898         # Pod port (must match container port)
```

**Change this to:**
- Change service type (ClusterIP, NodePort, LoadBalancer)
- Add additional ports

#### **3. apps/podinfo/tenants/demo/patch.yaml**
**What it does:** Tenant-specific customizations

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  replicas: 2                # Override base replicas

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: tenant-demo
spec:
  ingressClassName: nginx
  rules:
  - host: demo.localhost     # HTTP routing rule
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: podinfo    # Routes to podinfo service
            port:
              number: 9898
```

**Change this to:**
- Scale replicas
- Change hostname (demo.localhost → myapp.localhost)
- Add multiple hosts/paths

#### **4. apps/podinfo/tenants/demo/kustomization.yaml**
**What it does:** Combines base + overlay

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tenant-demo       # All resources deployed here
resources:
- ../../base                 # Include base manifests
patches:
- path: patch.yaml           # Apply tenant-specific changes
```

### **How to Apply Manifests:**

#### **Option A: kubectl apply (Direct)**
```bash
# Apply base only
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/base/

# Apply tenant overlay (includes base + patches)
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
```

#### **Option B: Preview Before Applying**
```bash
# See what would be applied (dry-run)
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/ --dry-run=client -o yaml

# See differences (if already deployed)
kubectl diff -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
```

#### **Option C: Delete and Recreate**
```bash
# Delete
kubectl delete -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/

# Apply
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
```

### **Common Manifest Changes:**

#### **Change 1: Scale to 3 Replicas**
```bash
vim ~/agent-ready-k8s/apps/podinfo/tenants/demo/patch.yaml

# Change:
# spec:
#   replicas: 2  →  replicas: 3

kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
kubectl get pods -n tenant-demo -w
```

#### **Change 2: Update Image Version**
```bash
vim ~/agent-ready-k8s/apps/podinfo/base/deployment.yaml

# Change:
# image: ghcr.io/stefanprodan/podinfo:6.9.2
#   →  ghcr.io/stefanprodan/podinfo:6.9.3

kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
kubectl rollout status deployment/podinfo -n tenant-demo
```

#### **Change 3: Add Second Host**
```bash
vim ~/agent-ready-k8s/apps/podinfo/tenants/demo/patch.yaml

# Add in Ingress rules:
# - host: demo2.localhost
#   http:
#     paths:
#     - path: /
#       pathType: Prefix
#       backend:
#         service:
#           name: podinfo
#           port:
#             number: 9898

# Add to /etc/hosts
echo "127.0.0.1 demo2.localhost" | sudo tee -a /etc/hosts

kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
curl http://demo2.localhost
```

---

## 🔧 Troubleshooting & Debugging

### **Problem: Pod Won't Start**

```bash
# 1. Check pod status
kubectl get pods -n tenant-demo
# STATUS: Pending, CrashLoopBackOff, ImagePullBackOff?

# 2. See detailed error
kubectl describe pod -n tenant-demo podinfo-xxx
# Look at: Events section (bottom)

# 3. Check logs
kubectl logs -n tenant-demo podinfo-xxx
# If pod crashed:
kubectl logs -n tenant-demo podinfo-xxx --previous

# Common causes:
# - ImagePullBackOff → Wrong image name or Docker Hub rate limit
# - CrashLoopBackOff → App crashes on startup (check logs)
# - Pending → Not enough resources (check: kubectl describe node)
```

### **Problem: Service Not Reachable**

```bash
# 1. Check if pods are running
kubectl get pods -n tenant-demo
# All must be: Running + Ready 1/1

# 2. Check if service has endpoints
kubectl get endpoints -n tenant-demo podinfo
# Must show pod IPs (e.g., 10.244.0.5:9898)

# 3. Test service from inside cluster
kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- \
  curl -s http://podinfo.tenant-demo.svc.cluster.local:9898
# Expected: JSON response

# If no endpoints → Service selector wrong
kubectl describe svc -n tenant-demo podinfo | grep Selector
kubectl get pods -n tenant-demo --show-labels
# Labels must match selector!
```

### **Problem: Ingress Returns 503**

```bash
# 1. Check ingress controller is running
kubectl get pods -n ingress-nginx
# Must be: Running + Ready 1/1

# 2. Check ingress configuration
kubectl describe ingress -n tenant-demo podinfo
# Look at: Backend section (should show pod IPs)

# 3. Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
# Look for errors related to demo.localhost

# 4. Check if service is reachable from ingress controller
kubectl exec -n ingress-nginx $(kubectl get pod -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- curl -s http://podinfo.tenant-demo.svc.cluster.local:9898
# Expected: JSON response
```

### **Problem: High CPU/Memory**

```bash
# 1. Check resource usage
kubectl top pods -n tenant-demo

# 2. Check resource limits
kubectl describe pod -n tenant-demo podinfo-xxx | grep -A 5 "Limits"

# 3. See detailed pod metrics
kubectl get pod -n tenant-demo podinfo-xxx -o json | jq '.status.containerStatuses[0].resources'

# 4. If pod is OOMKilled (Out of Memory):
kubectl describe pod -n tenant-demo podinfo-xxx | grep OOMKilled
# → Increase memory limits in deployment.yaml
```

### **Problem: Changes Not Applied**

```bash
# 1. Verify file was edited
cat ~/agent-ready-k8s/apps/podinfo/tenants/demo/patch.yaml

# 2. Apply with verbose output
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/ -v=8

# 3. Check if deployment was updated
kubectl get deployment -n tenant-demo podinfo -o yaml | grep replicas

# 4. Force recreation
kubectl delete -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
```

---

## 🚀 Advanced Operations

### **1. Port Forwarding (Direct Pod Access)**

```bash
# Forward pod port to localhost
kubectl port-forward -n tenant-demo podinfo-xxx 9898:9898 &

# Access pod directly
curl http://localhost:9898

# Forward service (load-balanced)
kubectl port-forward -n tenant-demo svc/podinfo 9898:9898 &

# Kill port-forward
pkill -f "port-forward"
```

### **2. Execute Commands in Pod**

```bash
# Interactive shell
kubectl exec -n tenant-demo -it podinfo-xxx -- /bin/sh

# Single command
kubectl exec -n tenant-demo podinfo-xxx -- ls -la /

# Check pod environment
kubectl exec -n tenant-demo podinfo-xxx -- env
```

### **3. Copy Files To/From Pod**

```bash
# Copy file to pod
kubectl cp /tmp/config.json tenant-demo/podinfo-xxx:/tmp/config.json

# Copy file from pod
kubectl cp tenant-demo/podinfo-xxx:/var/log/app.log /tmp/app.log
```

### **4. Watch Resources in Real-Time**

```bash
# Watch pods
kubectl get pods -n tenant-demo -w

# Watch events
kubectl get events -n tenant-demo -w

# Watch with custom columns
kubectl get pods -n tenant-demo -w -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP
```

### **5. Export Resources (Backup)**

```bash
# Export all resources in namespace
kubectl get all -n tenant-demo -o yaml > /tmp/tenant-demo-backup.yaml

# Export specific resource
kubectl get deployment -n tenant-demo podinfo -o yaml > /tmp/podinfo-deployment.yaml

# Restore from backup
kubectl apply -f /tmp/tenant-demo-backup.yaml
```

### **6. Performance Testing**

```bash
# Load test with ab (Apache Bench)
sudo apt install apache2-utils
ab -n 1000 -c 10 http://demo.localhost/

# Watch pod resource usage during test
watch -n 1 kubectl top pods -n tenant-demo

# Check if HPA scales automatically
kubectl get hpa -n tenant-demo -w
# (Only if HPA is configured)
```

---

## 📚 Summary: Key Commands Reference

### **Daily Operations:**
```bash
# Check everything
kubectl get all -A

# Check specific app
kubectl get pods -n tenant-demo
kubectl logs -n tenant-demo -l app=podinfo -f
curl http://demo.localhost

# Scale app
kubectl scale deployment podinfo -n tenant-demo --replicas=3

# Restart app
kubectl rollout restart deployment/podinfo -n tenant-demo

# Update from manifests
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
```

### **Debugging:**
```bash
# Pod issues
kubectl describe pod -n tenant-demo podinfo-xxx
kubectl logs -n tenant-demo podinfo-xxx --previous

# Service issues
kubectl get endpoints -n tenant-demo podinfo

# Ingress issues
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50

# Resource usage
kubectl top nodes
kubectl top pods -n tenant-demo
```

### **Management:**
```bash
# Delete and recreate
kubectl delete -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/
kubectl apply -k ~/agent-ready-k8s/apps/podinfo/tenants/demo/

# Complete cleanup
kind delete cluster --name agent-k8s-local

# Recreate everything
~/agent-ready-k8s/setup-template/setup-phase1.sh
```

---

## 🎓 Next Steps

1. **Practice:** Change replicas, image versions, environment variables
2. **Monitor:** Use `k9s` for visual overview
3. **Experiment:** Deploy second app (nginx, redis, etc.)
4. **Learn GitOps:** Prepare for Phase 2 (Flux auto-deployment)

**📖 See also:**
- `Quickstart.md` - Setup guide
- `ROADMAP.md` - Phase 2 planning
- `.github/copilot-instructions.md` - Project structure

---

**Last Updated:** 05.10.2025  
**Your Cluster:** agent-k8s-local (kind v0.20.0, K8s v1.27.3)  
**Your App:** podinfo v6.9.2 @ http://demo.localhost
