# Runbook: Config Hot-Reload Troubleshooting

> **⚠️ STATUS: ACTIVE (with placeholders)**
>
> This runbook is usable for debugging config hot-reload issues.
> **Note:** Namespace references use `<namespace>` placeholders. Replace with your actual namespace (e.g., `demo-platform`, `tenant-acme`).
> **Action Required:** Once namespace strategy is finalized, replace all `<namespace>` placeholders.

---

> **Purpose:** Debug and resolve config hot-reload issues (PostgreSQL + Redis Pub/Sub).
>
> **Audience:** SRE, Backend Engineers, On-Call
>
> **Related:** [ADR-0001 Config SoT SQL](../adr/ADR-0001-config-sot-sql.md), [ADR-0002 Hot-Reload Redis](../adr/ADR-0002-hot-reload-redis.md)

---

## Overview

**Config Hot-Reload Flow:**
1. User updates config via API → Backend writes to **PostgreSQL** (Source of Truth)
2. Backend publishes event to **Redis Pub/Sub** (`config:ai:threshold version=5`)
3. All backend pods (subscribed) receive event in **<100ms**
4. Pods fetch new value from PostgreSQL
5. Pods update **in-memory config** (no restart)

**Expected Latency:** <100ms from PostgreSQL UPDATE to all pods updated.

---

## 1. Symptoms & Diagnostics

### Symptom 1: "Config not updating after change"

**User report:** "I updated AI threshold to 0.85, but backend still uses 0.75"

**Debug steps:**

#### A. Check PostgreSQL (Source of Truth)

```bash
# Verify config was written to DB
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "SELECT key, value, version, updated_at FROM service_configs WHERE key='ai.threshold';"
```

**Expected output:**
```
      key       | value | version |       updated_at
----------------+-------+---------+------------------------
 ai.threshold   | 0.85  |       5 | 2025-10-20 14:30:00+00
```

**If version unchanged:**
- Config UPDATE failed → Check backend logs
- Wrong key name → Verify API request

---

#### B. Check Redis Pub/Sub Event

```bash
# Subscribe to config channel (listen for events)
kubectl exec -it redis-0 -n <namespace> -- redis-cli SUBSCRIBE "config:*"

# In another terminal, trigger config update
curl -X PUT https://api.platform.example.com/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -d '{"value": "0.85"}'

# Expected output in first terminal:
# 1) "message"
# 2) "config:ai:threshold"
# 3) "version=5"
```

**If no event received:**
- Redis Pub/Sub not working → Check Redis pod health
- Backend didn't publish → Check backend logs (`redis.publish` call)

---

#### C. Check Backend Pod (Subscriber)

```bash
# Check backend logs for hot-reload event
kubectl logs -n <namespace> backend-7c9e6679-abc12 --tail=100 | grep "config"

# Expected log:
# [INFO] Config hot-reload: ai.threshold version=5
# [INFO] Fetched new value from PostgreSQL: 0.85
# [INFO] Updated in-memory config: ai.threshold = 0.85
```

**If no log:**
- Pod not subscribed to Redis → Check Redis connection
- Pod crashed before receiving event → Check pod restarts
- Pod version drift → Check reconcile loop

---

#### D. Verify In-Memory Config

```bash
# Query backend /health endpoint (exposes config version)
curl https://api.platform.example.com/health | jq '.config_versions'

# Expected:
# {
#   "ai.threshold": 5,
#   "feature.chat": 3
# }
```

**If version is old (e.g., 4):**
- Pod missed Redis Pub/Sub event → Reconcile loop should fix it
- Reconcile loop not running → Check logs

---

### Symptom 2: "Hot-reload slow (>5 seconds)"

**Expected:** <100ms
**Actual:** 5-10 seconds

**Causes:**

#### A. Redis Pub/Sub Latency

```bash
# Measure Redis latency
kubectl exec -it redis-0 -n <namespace> -- redis-cli --latency

# Expected: <10ms
# If >100ms: Redis overloaded or network issue
```

**Fix:**
- Scale Redis (if CPU >80%)
- Check network policies (no throttling)

---

#### B. PostgreSQL Query Slow

```bash
# Check query duration
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "SELECT key, value FROM service_configs WHERE key='ai.threshold';"

# Expected: <50ms
# If >500ms: Missing index
```

**Fix:**
```sql
-- Add index (if missing)
CREATE INDEX CONCURRENTLY idx_service_configs_key ON service_configs(key);
```

---

#### C. Too Many Pods (Redis Fan-Out)

**Scenario:** 1000 backend pods subscribed → Redis publishes to 1000 connections

**Check:**
```bash
# Count Redis Pub/Sub subscribers
kubectl exec -it redis-0 -n <namespace> -- redis-cli PUBSUB NUMSUB "config:*"

# Expected: <100 subscribers
# If >1000: Redis may be slow
```

**Fix:**
- Use Redis Cluster (sharding)
- Reduce pod count (if over-provisioned)

---

### Symptom 3: "Some pods updated, others didn't"

**Scenario:** 10 backend pods, 8 updated to version 5, 2 still on version 4

**Causes:**

#### A. Pod Disconnected from Redis

```bash
# Check Redis connection per pod
for pod in $(kubectl get pods -n <namespace> -l app=backend -o name); do
  echo "=== $pod ==="
  kubectl exec -n <namespace> $pod -- sh -c "redis-cli -h redis PING"
done

# Expected: All pods return "PONG"
# If "Connection refused": Pod not connected
```

**Fix:**
- Check NetworkPolicy (allow backend → Redis)
- Restart pod: `kubectl delete pod backend-xyz`

---

#### B. Reconcile Loop Not Running

Reconcile loop (every 5-10 min) should detect version drift and fetch from PostgreSQL.

```bash
# Check reconcile loop logs
kubectl logs -n <namespace> backend-7c9e6679-abc12 --tail=100 | grep "reconcile"

# Expected (every 10 minutes):
# [INFO] Reconcile loop: Checking version drift
# [INFO] ai.threshold: local=4, db=5 → Drift detected
# [INFO] Fetching new value from PostgreSQL
```

**If no logs:**
- Reconcile loop disabled → Check config (`RECONCILE_ENABLED=true`)
- Reconcile loop crashed → Check error logs

---

## 2. Common Issues & Fixes

### Issue 1: Redis Unavailable

**Symptom:** Backend logs show `redis.exceptions.ConnectionError`
**Cause:** Redis pod down or unreachable

**Fix:**
```bash
# Check Redis pod
kubectl get pods -n <namespace> -l app=redis

# If CrashLoopBackOff:
kubectl logs -n <namespace> redis-0 --tail=100

# Restart Redis
kubectl delete pod redis-0 -n <namespace>
```

**Mitigation:** Reconcile loop will fetch from PostgreSQL (fallback).

---

### Issue 2: Version Drift (Out of Sync)

**Symptom:** Backend pod shows `ai.threshold=4`, but DB has `version=5`
**Cause:** Pod missed Redis Pub/Sub event (network blip)

**Fix:**
```bash
# Manually trigger reconcile (restart pod)
kubectl delete pod backend-7c9e6679-abc12 -n <namespace>

# Or wait for reconcile loop (runs every 10 minutes)
```

**Metrics:**
```yaml
# Prometheus query: Version drift
abs(config_version{key="ai.threshold", source="local"} - config_version{key="ai.threshold", source="db"})
```

---

### Issue 3: Config Key Typo

**Symptom:** User updates `ai.threshld` (typo), backend still uses old value
**Cause:** Wrong key name in API request

**Fix:**
```bash
# List all config keys
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "SELECT key FROM service_configs ORDER BY key;"

# Update correct key
curl -X PUT https://api.platform.example.com/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -d '{"value": "0.85"}'
```

---

### Issue 4: Redis Pub/Sub Channel Typo

**Symptom:** Backend publishes to `config:ai:threshld`, pods subscribed to `config:*` don't receive
**Cause:** Bug in backend code (channel name typo)

**Debug:**
```bash
# Monitor all Redis Pub/Sub channels
kubectl exec -it redis-0 -n <namespace> -- redis-cli PSUBSCRIBE "*"

# Trigger config update, check channel name in output
```

**Fix:** Fix channel name in backend code, redeploy.

---

## 3. Monitoring

### Metrics (Prometheus)

```yaml
# Config version per pod (local vs. DB)
config_version{key, source="local", pod}
config_version{key, source="db"}

# Hot-reload latency (histogram)
config_reload_duration_seconds{key}

# Hot-reload errors
config_reload_errors_total{key, error_type}

# Version drift (alert if drift >0 for >15 min)
abs(config_version{source="local"} - config_version{source="db"})
```

### Alerts

```yaml
alert: ConfigHotReloadSlow
expr: histogram_quantile(0.95, config_reload_duration_seconds) > 0.5
for: 5m
severity: warning
annotations:
  summary: "Config hot-reload is slow (P95 > 500ms)"

alert: ConfigVersionDrift
expr: abs(config_version{source="local"} - config_version{source="db"}) > 0
for: 15m
severity: warning
annotations:
  summary: "Config version drift detected (pod out of sync for >15 min)"

alert: ConfigReloadErrors
expr: rate(config_reload_errors_total[5m]) > 0.1
for: 5m
severity: critical
annotations:
  summary: "High config reload error rate"
```

### Logs

```bash
# Backend logs (config hot-reload events)
kubectl logs -n <namespace> -l app=backend --tail=100 | grep "config"

# Redis logs (Pub/Sub activity)
kubectl logs -n <namespace> redis-0 | grep PUBLISH
```

---

## 4. Manual Testing

### Test 1: End-to-End Hot-Reload

```bash
# 1. Subscribe to Redis Pub/Sub (monitor events)
kubectl exec -it redis-0 -n <namespace> -- redis-cli SUBSCRIBE "config:*"

# 2. Update config via API
curl -X PUT https://api.platform.example.com/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -d '{"value": "0.99"}'

# 3. Check Redis event (should appear in <100ms)
# Expected:
# 1) "message"
# 2) "config:ai:threshold"
# 3) "version=6"

# 4. Check backend pod logs
kubectl logs -n <namespace> backend-7c9e6679-abc12 --tail=10 | grep "ai.threshold"

# Expected:
# [INFO] Config hot-reload: ai.threshold version=6
# [INFO] Updated in-memory config: ai.threshold = 0.99
```

---

### Test 2: Reconcile Loop (Version Drift)

```bash
# 1. Manually update PostgreSQL (bypass API)
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "UPDATE service_configs SET value='0.88', version=version+1 WHERE key='ai.threshold';"

# 2. Wait 10 minutes (reconcile loop interval)

# 3. Check backend pod logs
kubectl logs -n <namespace> backend-7c9e6679-abc12 --tail=10 | grep "reconcile"

# Expected:
# [INFO] Reconcile loop: ai.threshold drift detected (local=6, db=7)
# [INFO] Fetching new value from PostgreSQL
# [INFO] Updated in-memory config: ai.threshold = 0.88
```

---

### Test 3: Redis Unavailable (Fallback)

```bash
# 1. Stop Redis
kubectl scale statefulset redis -n <namespace> --replicas=0

# 2. Update config via API (should still work)
curl -X PUT https://api.platform.example.com/api/configs/ai.threshold \
  -H "Authorization: Bearer $JWT" \
  -d '{"value": "0.77"}'

# 3. Check backend logs (no Redis Pub/Sub, but reconcile loop should fetch)
kubectl logs -n <namespace> backend-7c9e6679-abc12 --tail=10 | grep "reconcile"

# Expected (after 10 minutes):
# [INFO] Reconcile loop: ai.threshold drift detected
# [INFO] Updated in-memory config: ai.threshold = 0.77

# 4. Restart Redis
kubectl scale statefulset redis -n <namespace> --replicas=1
```

---

## 5. Emergency Procedures

### Procedure 1: Force Config Reload (All Pods)

**Scenario:** Config not propagating, need immediate reload.

```bash
# Option 1: Restart all backend pods (rolling restart)
kubectl rollout restart deployment backend -n <namespace>

# Option 2: Trigger reconcile loop manually (if exposed in API)
curl -X POST https://api.platform.example.com/admin/reconcile \
  -H "Authorization: Bearer $ADMIN_JWT"
```

---

### Procedure 2: Rollback Config (Bad Value)

**Scenario:** Updated `ai.threshold` to invalid value (e.g., `-1`), need rollback.

```bash
# 1. Check config history
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "SELECT version, value, updated_at FROM config_history WHERE key='ai.threshold' ORDER BY version DESC LIMIT 5;"

# 2. Rollback to previous version
kubectl exec -it postgresql-0 -n <namespace> -- psql -U postgres -d demo-platform -c \
  "UPDATE service_configs SET value='0.75', version=version+1 WHERE key='ai.threshold';"

# 3. Publish Redis event (trigger hot-reload)
kubectl exec -it redis-0 -n <namespace> -- redis-cli PUBLISH "config:ai:threshold" "version=8"

# 4. Verify all pods updated
curl https://api.platform.example.com/health | jq '.config_versions'
```

---

## 6. Troubleshooting Decision Tree

```
Config not updating?
├─ PostgreSQL value wrong?
│  ├─ Yes → Fix value in DB, publish Redis event
│  └─ No → Check Redis Pub/Sub
├─ Redis event not published?
│  ├─ Yes → Check backend logs (redis.publish call)
│  └─ No → Check Redis Pub/Sub subscribers
├─ Pod not subscribed to Redis?
│  ├─ Yes → Restart pod, check NetworkPolicy
│  └─ No → Check reconcile loop
└─ Reconcile loop not running?
   ├─ Yes → Enable reconcile loop (RECONCILE_ENABLED=true)
   └─ No → Manual restart (kubectl delete pod)
```

---

## 7. Postmortem Template

### Incident: Config Hot-Reload Failure

**Date:** 2025-10-20 14:30 UTC
**Duration:** 15 minutes
**Impact:** AI threshold not updated for 2/10 backend pods (20% of users affected)

**Root Cause:**
- Redis Pub/Sub event published to wrong channel (`config:ai:threshld` instead of `config:ai:threshold`)
- 2 pods subscribed to `config:ai:threshold` didn't receive event
- Reconcile loop detected drift after 10 minutes and fixed issue

**Resolution:**
- Fixed channel name typo in backend code
- Redeployed backend

**Action Items:**
- [ ] Add integration test for Redis Pub/Sub channel names
- [ ] Reduce reconcile loop interval from 10 min → 5 min
- [ ] Add alert for version drift (>15 min)

---

## References

- [ADR-0001: Config SoT = PostgreSQL](../adr/ADR-0001-config-sot-sql.md)
- [ADR-0002: Hot-Reload via Redis Pub/Sub](../adr/ADR-0002-hot-reload-redis.md)
- [Redis Pub/Sub Documentation](https://redis.io/docs/manual/pubsub/)
- [PostgreSQL Audit Trail](https://www.postgresql.org/docs/current/sql-createtrigger.html)
