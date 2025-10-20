# ADR-0002: Hot-Reload via Redis Pub/Sub (not Polling)

> **Status:** Accepted
> **Date:** 20 October 2025
> **Deciders:** Platform Team, Backend Team
> **Related:** ADR-0001 (Config SoT), ADR-0003 (etcd Scope)

## Context

Application configs (AI thresholds, feature flags, quotas) must be hot-reloadable **without pod restarts**. Changes must propagate to **all backend pods** in **<100ms**.

### Requirements

1. **Real-Time** - Config changes apply in <100ms
2. **Multi-Pod Sync** - All N backend pods receive updates simultaneously
3. **No Restart** - Pods update in-memory config without restart
4. **Reliable** - No missed updates (fallback reconciliation)
5. **Simple** - Minimal code, easy to debug

### Options Considered

1. **Redis Pub/Sub** (event-driven push)
2. **PostgreSQL Polling** (periodic SELECT)
3. **etcd Watch API** (K8s-native watch)
4. **ConfigMap + Reloader** (K8s-native, requires restart)

---

## Decision

**We will use Redis Pub/Sub for config hot-reload push notifications.**

### Rationale

#### Why Redis Pub/Sub?

✅ **<100ms Latency** - Events delivered in <50ms
✅ **Broadcast** - One PUBLISH → all subscribed pods receive simultaneously
✅ **No Polling** - Event-driven, no DB load
✅ **Simple API** - 5 lines of code (SUBSCRIBE, PUBLISH)
✅ **Ephemeral** - No persistence needed (PostgreSQL is SoT)
✅ **Scalable** - Handles 1000+ pods efficiently

#### Why NOT PostgreSQL Polling?

❌ **5-60s Delay** - Polling interval = latency
❌ **DB Load** - Every pod polls every 5s = high load
❌ **Asynchronous** - Pods update at different times (inconsistent state)

#### Why NOT etcd Watch API?

❌ **Vendor Lock-In** - K8s-specific, not portable
❌ **Complex Setup** - Requires K8s API access, mTLS, RBAC
❌ **Not Designed for Apps** - etcd is for K8s control plane
❌ **Compaction Errors** - Watch clients must handle compaction restarts

#### Why NOT ConfigMap + Reloader?

❌ **Pod Restart Required** - Reloader triggers rolling restart (15-30s downtime per pod)
❌ **No True Hot-Reload** - Restarts = downtime

---

## Consequences

### Positive

- ✅ **Fast** - <100ms from config change to all pods updated
- ✅ **Simple** - Minimal code (SUBSCRIBE + PUBLISH)
- ✅ **Scalable** - Handles 1000+ pods without performance issues
- ✅ **No DB Load** - Polling eliminated
- ✅ **Consistent State** - All pods update simultaneously

### Negative

- ⚠️ **Extra Dependency** - Requires Redis (adds operational complexity)
- ⚠️ **Ephemeral Events** - Missed events if pod disconnected (mitigated by reconcile loop)

### Risks

- **Risk 1:** Redis unavailable = hot-reload broken
  - **Mitigation:** Pods cache last-known config in memory; reconcile loop fetches from PostgreSQL every 5-10 min
- **Risk 2:** Pod misses PUBLISH event (network issue)
  - **Mitigation:** Reconcile loop (every 5-10 min) queries PostgreSQL for version drift
- **Risk 3:** Secrets leaked in Redis Pub/Sub channels
  - **Mitigation:** **Never publish secret values**; only publish version IDs/event types

---

## Implementation

### Flow

```
1. User updates config → Backend API
2. Backend writes to PostgreSQL (SoT)
3. Backend publishes event to Redis: PUBLISH config:ai:threshold "version=5"
4. All backend pods (subscribed) receive event
5. Pods check local version (4) vs. new version (5)
6. Pods fetch new value from PostgreSQL
7. Pods update in-memory config
```

### Redis Pub/Sub Commands

#### Backend (Publisher)

```python
# After PostgreSQL UPDATE
await redis.publish("config:ai:threshold", f"version={new_version}")
```

#### Backend Pods (Subscribers)

```python
# Startup: Subscribe to all config channels
pubsub = redis.pubsub()
pubsub.subscribe("config:*")

# Background thread: Listen for events
async for message in pubsub.listen():
    if message["type"] == "message":
        channel = message["channel"]  # "config:ai:threshold"
        version = message["data"]     # "version=5"
        
        # Check if newer version
        if int(version) > local_version:
            # Fetch new value from PostgreSQL (SoT)
            new_value = await db.query(
                "SELECT value FROM service_configs WHERE key = ?", 
                key
            )
            # Update in-memory config
            config[key] = new_value
            local_version = int(version)
```

---

## Security Hardening

### Redis ACL (Access Control)

```redis
# Subscriber pods: only SUBSCRIBE allowed
ACL SETUSER backend-pod on >password ~config:* +subscribe -@all
```

### TLS Encryption

```yaml
# Redis connection with TLS
rediss://redis.svc.cluster.local:6379?tls=true
```

### No Secrets in Channels

**Rule:** Redis Pub/Sub carries **only version IDs**, never secret values.

**Example (BAD):**
```python
await redis.publish("config:db:password", "mySecretPassword123")  # ❌ NEVER!
```

**Example (GOOD):**
```python
await redis.publish("config:db:password", "version=7")  # ✅ Only version
# Pods fetch actual secret from PostgreSQL or ESO
```

---

## Resiliency

### Warm-Load on Startup

```python
# Pod startup: Load all configs from PostgreSQL (SoT)
async def startup():
    configs = await db.query("SELECT * FROM service_configs WHERE org_id = ?", org_id)
    for config in configs:
        in_memory_config[config.key] = config.value
        local_versions[config.key] = config.version
    
    # Then subscribe to Redis for updates
    pubsub.subscribe("config:*")
```

### Reconcile Loop (Fallback)

```python
# Every 5-10 minutes: Check for version drift
async def reconcile():
    while True:
        await asyncio.sleep(600)  # 10 minutes
        
        db_versions = await db.query("SELECT key, version FROM service_configs")
        for row in db_versions:
            if row.version > local_versions.get(row.key, 0):
                # Missed a PUBLISH event! Reload from DB
                new_value = await db.query("SELECT value WHERE key = ?", row.key)
                config[row.key] = new_value
                local_versions[row.key] = row.version
```

---

## Monitoring

### Metrics

- `config_version{org_id, service, key}` - Current version per pod
- `config_reload_duration_seconds` - Hot-reload latency (histogram)
- `config_reload_errors_total` - Failed reloads (counter)
- `config_version_drift` - Difference between DB and local version

### Alerts

```yaml
alert: ConfigHotReloadSlow
expr: histogram_quantile(0.95, config_reload_duration_seconds) > 0.5
for: 5m
severity: warning
```

```yaml
alert: ConfigVersionDrift
expr: config_version_drift > 0
for: 15m
severity: warning
```

---

## Alternatives Rejected

### Option 1: PostgreSQL Polling

**Rejected because:**
- 5-60s delay (not real-time)
- High DB load (all pods poll every 5s)
- Inconsistent state (pods update at different times)

**When to use polling:**
- Acceptable latency (5-60s)
- No Redis available
- Very low traffic (<10 config changes/day)

### Option 2: etcd Watch API

**Rejected because:**
- Vendor lock-in to Kubernetes
- Complex setup (K8s API access, mTLS)
- Compaction errors require complex retry logic
- Not designed for application config

**When to use etcd:**
- K8s control plane only
- Distributed coordination (leader election)

---

## References

- [Redis Pub/Sub Documentation](https://redis.io/docs/manual/pubsub/)
- [Redis ACL](https://redis.io/docs/management/security/acl/)
- [Redis TLS](https://redis.io/docs/manual/security/encryption/)
- ADR-0001: Config Source of Truth = PostgreSQL
- ADR-0003: etcd Scope (K8s Control Plane Only)
