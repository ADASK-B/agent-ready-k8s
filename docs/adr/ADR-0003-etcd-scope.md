# ADR-0003: etcd Scope Limited to K8s Control Plane Only

> **Status:** Accepted
> **Date:** 20 October 2025
> **Deciders:** Platform Team, Backend Team
> **Related:** ADR-0001 (Config SoT), ADR-0002 (Hot-Reload)

## Context

etcd is the distributed key-value store used by Kubernetes as its control plane database. It stores K8s resources (Pods, Services, ConfigMaps, etc.) and provides strong consistency via Raft consensus.

### Question

**Should we use etcd directly in application code for:**
- Application config storage?
- Feature flags?
- Distributed locks?
- Leader election?

### Current State

- **K8s Control Plane** uses etcd for all resources
- **Application config** is in PostgreSQL (ADR-0001)
- **Hot-reload** uses Redis Pub/Sub (ADR-0002)

---

## Decision

**We will NOT use etcd directly in application code. etcd is ONLY for K8s control plane.**

Application-level config, state, and coordination will use **PostgreSQL + Redis**.

---

## Rationale

### Why NOT Use etcd for Application Config?

#### 1. Vendor Lock-In to Kubernetes

etcd is K8s-specific. If we migrate to a managed service (AWS ECS, Azure App Service, Cloud Run), we lose etcd entirely.

**Example scenario:**
```yaml
# Today: K8s self-managed
etcd → works

# Tomorrow: AWS ECS + RDS
etcd → gone (not available in ECS)
```

#### 2. Complex Access Control

Accessing etcd from application code requires:
- **K8s API access** (ServiceAccount + RBAC)
- **mTLS certificates** (CA, client cert)
- **Watch restart logic** (handle compaction errors)

**Code complexity:**
```go
// PostgreSQL (Simple)
db.Query("SELECT value FROM configs WHERE key = ?", key)

// etcd (Complex)
client, _ := clientv3.New(clientv3.Config{
    Endpoints: []string{"etcd.kube-system.svc:2379"},
    TLS: &tls.Config{
        Certificates: []tls.Certificate{clientCert},
        RootCAs:      caPool,
    },
})
resp, _ := client.Get(ctx, "/config/ai_threshold")
```

#### 3. Not Designed for Application Data

etcd is optimized for:
- **Small datasets** (<8GB)
- **Control plane objects** (Pods, Services)
- **Distributed coordination** (leader election)

etcd is NOT designed for:
- **Large datasets** (>8GB, e.g., chat history, audit logs)
- **SQL queries** (no joins, no indexes beyond key prefix)
- **Long-term retention** (12-36 month audit logs)

#### 4. Operational Risk

**If etcd fails, K8s control plane fails.** Do we want application bugs to risk the entire K8s cluster?

**Risk scenario:**
```
Application code has bug → writes 100K keys/sec to etcd
→ etcd disk full → etcd crashes
→ K8s API server down → ALL pods can't schedule/restart
→ Complete cluster outage
```

#### 5. No SQL Features

etcd does NOT support:
- SQL joins
- Complex queries
- Full-text search
- Foreign keys
- Row-level security (RLS)
- Audit trail (triggered by triggers)

**Example:**
```sql
-- PostgreSQL: Find all configs for org
SELECT * FROM service_configs WHERE org_id = ? AND updated_at > ?

-- etcd: Requires app-level filtering
resp, _ := client.Get(ctx, "/config/", clientv3.WithPrefix())
for _, kv := range resp.Kvs {
    // Manual filtering in app code
}
```

---

## What etcd IS Good For (K8s Only)

✅ **K8s Control Plane** - Pods, Services, Deployments, ConfigMaps, Secrets
✅ **Distributed Coordination** - Leader election (via K8s Lease API)
✅ **Consistency** - Strong consistency via Raft (critical for K8s)

---

## Consequences

### Positive

- ✅ **Portable** - PostgreSQL + Redis work outside K8s (ECS, App Service)
- ✅ **Simple Access** - No K8s API, no mTLS, no RBAC complexity
- ✅ **Separation of Concerns** - App bugs don't risk K8s control plane
- ✅ **SQL Features** - Joins, indexes, RLS, audit triggers
- ✅ **Scalability** - PostgreSQL handles >8GB datasets

### Negative

- ⚠️ **No K8s-Native Watch** - Must use Redis Pub/Sub instead (ADR-0002)
- ⚠️ **Distributed Locks** - Must use PostgreSQL advisory locks (not etcd)

---

## Implementation

### Correct: Use PostgreSQL + Redis

```python
# Config storage (SoT)
await db.execute(
    "UPDATE service_configs SET value = ? WHERE key = ?",
    new_value, key
)

# Hot-reload push
await redis.publish("config:ai:threshold", f"version={version}")

# Distributed lock (PostgreSQL advisory lock)
async with db.execute("SELECT pg_advisory_lock(?)") as lock:
    # Critical section
    pass
```

### Incorrect: Direct etcd Access (DON'T DO THIS)

```python
# ❌ NEVER DO THIS
import etcd3
client = etcd3.client(host="etcd.kube-system.svc", port=2379)
client.put("/config/ai_threshold", "0.85")
```

---

## When to Use etcd (Via K8s API)

### Acceptable Use Case 1: Leader Election

Use **K8s Lease API** (backed by etcd) for leader election:

```yaml
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: backend-leader
  namespace: default
spec:
  holderIdentity: pod-12345
  leaseDurationSeconds: 15
```

**Why acceptable:**
- K8s abstraction (not direct etcd access)
- Portable (Lease API works on EKS, AKS, GKE)
- No risk to etcd (K8s API handles rate limiting)

### Acceptable Use Case 2: ConfigMaps (Cold Config)

Use **ConfigMaps** for **immutable, cold config** (not hot-reload):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-env
data:
  LOG_LEVEL: info
  DB_POOL_SIZE: "20"
```

**Why acceptable:**
- K8s abstraction (not direct etcd access)
- Immutable (requires pod restart to change)
- Low write frequency (<1 write/hour)

**NOT for:**
- Hot-reload config (use PostgreSQL + Redis)
- Secrets (use External Secrets Operator + KMS)
- High write frequency (>1 write/min)

---

## Migration Scenarios

### Scenario 1: K8s → AWS ECS

| Component          | K8s                | AWS ECS           |
| ------------------ | ------------------ | ----------------- |
| Orchestrator       | K8s                | ECS               |
| Service Discovery  | K8s Service        | AWS Cloud Map     |
| Secrets            | ESO + KMS          | ESO + Secrets Mgr |
| Config (SoT)       | **PostgreSQL RDS** | **PostgreSQL RDS** |
| Hot-Reload         | **Redis**          | **Redis**         |
| etcd               | K8s control plane  | **Not available** |

✅ **PostgreSQL + Redis are portable** → No migration needed
❌ **etcd is gone** → If app used etcd directly, must rewrite

### Scenario 2: K8s → Cloud Run (Serverless)

| Component          | K8s                | Cloud Run         |
| ------------------ | ------------------ | ----------------- |
| Orchestrator       | K8s                | Cloud Run         |
| Service Discovery  | K8s Service        | Cloud Run URL     |
| Secrets            | ESO + KMS          | Secret Manager    |
| Config (SoT)       | **PostgreSQL**     | **PostgreSQL**    |
| Hot-Reload         | **Redis**          | **Redis Memorystore** |
| etcd               | K8s control plane  | **Not available** |

✅ **PostgreSQL + Redis are portable**
❌ **etcd is gone**

---

## Alternatives Rejected

### Option 1: Use etcd for Application Config

**Rejected because:**
- Vendor lock-in to K8s
- Complex access (mTLS, RBAC)
- Risk to K8s control plane
- No SQL features (joins, RLS)
- Not portable

**When to use:**
- Never (use PostgreSQL + Redis instead)

### Option 2: Use etcd for Feature Flags

**Rejected because:**
- ConfigMaps (backed by etcd) require pod restart
- Direct etcd access = vendor lock-in
- PostgreSQL + Redis provide hot-reload

**When to use:**
- Immutable config only (ConfigMaps acceptable)

### Option 3: Use etcd for Distributed Locks

**Rejected because:**
- Direct etcd access = vendor lock-in
- PostgreSQL advisory locks are simpler

**When to use:**
- Leader election only (via K8s Lease API)

---

## Decision Tree

```
Need distributed coordination?
├─ Leader election? → K8s Lease API (backed by etcd) ✅
├─ Distributed lock? → PostgreSQL advisory lock ✅
└─ Multi-leader consensus? → PostgreSQL + Redis Pub/Sub ✅

Need config storage?
├─ Hot-reload? → PostgreSQL + Redis Pub/Sub (ADR-0001, ADR-0002) ✅
├─ Immutable? → ConfigMap (backed by etcd, requires restart) ✅
└─ SQL queries? → PostgreSQL ✅

Need state storage?
├─ Long-term (12-36mo)? → PostgreSQL ✅
├─ Large dataset (>8GB)? → PostgreSQL ✅
└─ Ephemeral cache? → Redis ✅

Direct etcd access from app code? → ❌ NEVER
```

---

## Monitoring

### Metrics (K8s etcd Only)

```yaml
# Monitor K8s control plane etcd health (Prometheus)
etcd_server_has_leader == 1  # etcd cluster has leader
etcd_mvcc_db_total_size_in_bytes < 8GB  # Disk usage
etcd_network_peer_round_trip_time_seconds < 0.05  # Latency
```

### Alerts

```yaml
alert: EtcdNoLeader
expr: etcd_server_has_leader == 0
for: 1m
severity: critical

alert: EtcdHighLatency
expr: histogram_quantile(0.99, etcd_disk_wal_fsync_duration_seconds) > 0.1
for: 5m
severity: warning
```

---

## References

- [etcd Documentation](https://etcd.io/docs/)
- [K8s etcd Best Practices](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/)
- [K8s Lease API](https://kubernetes.io/docs/concepts/architecture/leases/)
- ADR-0001: Config Source of Truth = PostgreSQL
- ADR-0002: Hot-Reload via Redis Pub/Sub
