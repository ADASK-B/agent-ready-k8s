# Runbook: Incident Triage & Response

> **Purpose:** Standardized incident response process (detection → resolution → postmortem).
>
> **Audience:** On-Call Engineers, SRE, Support
>
> **Related:** [observability-strategy.md](../architecture/observability-strategy.md), [SECURITY.md](../../SECURITY.md)

---

## Incident Severity Levels

| Severity | Impact                                  | Response Time | Escalation            | Examples                                |
| -------- | --------------------------------------- | ------------- | --------------------- | --------------------------------------- |
| **SEV-1** | Complete outage (all users affected)   | <15 min       | CTO, CEO              | PostgreSQL down, K8s cluster down       |
| **SEV-2** | Major feature broken (>50% users)      | <1 hour       | Engineering Manager   | API 500 errors, Auth broken             |
| **SEV-3** | Minor feature degraded (<10% users)    | <4 hours      | On-Call Engineer      | Config hot-reload slow, Chat lag        |
| **SEV-4** | Cosmetic issue (no user impact)        | Next business day | Backlog            | Dashboard typo, Missing tooltip         |

---

## 1. Incident Detection

### Automated Alerts (PagerDuty/Slack)

**Critical Alerts (SEV-1):**
- PostgreSQL down (`pg_up == 0`)
- Redis down (`redis_up == 0`)
- API error rate >5% (`rate(http_requests_total{status=~"5.."}[5m]) > 0.05`)
- Cluster unreachable (Prometheus scrape failing)

**Warning Alerts (SEV-2/SEV-3):**
- High latency (P95 > 1s)
- Config hot-reload slow (>500ms)
- Backup failed (no backup in 48h)

### User Reports

1. **User submits ticket** (support@example.com)
2. **Support triages** (SEV-1/2/3/4)
3. **On-Call notified** (PagerDuty/Slack)

---

## 2. Incident Response Workflow

### Phase 1: Detection (0-5 min)

#### On-Call Receives Alert

**PagerDuty Alert Example:**
```
🚨 SEV-1: PostgreSQL Down
Cluster: production
Metric: pg_up == 0
Runbook: https://docs.example.com/runbooks/sql-backup-restore
```

#### Initial Actions

1. **Acknowledge alert** (PagerDuty)
2. **Create incident** (PagerDuty/Jira)
3. **Open war room** (Slack: `#incident-2025-10-20`)
4. **Post initial update** (Slack):
   ```
   🚨 SEV-1 Incident: PostgreSQL Down
   Impact: All users unable to access platform
   On-Call: @alice
   Status: Investigating
   ```

---

### Phase 2: Investigation (5-15 min)

#### Triage Questions

1. **When did it start?** (Check Grafana timeline)
2. **What changed?** (Check recent deployments, config changes)
3. **How many users affected?** (All, some, specific feature)
4. **Is data at risk?** (Data loss, corruption)

#### Quick Checks

##### A. Check K8s Pods

```bash
kubectl get pods -n default

# Expected: All pods "Running"
# If CrashLoopBackOff: Check logs
kubectl logs -n default postgresql-0 --tail=100
```

##### B. Check Health Endpoints

```bash
# API health
curl https://api.platform.example.com/health/ready

# PostgreSQL health
kubectl exec -it postgresql-0 -n default -- psql -U postgres -c "SELECT 1;"

# Redis health
kubectl exec -it redis-0 -n default -- redis-cli PING
```

##### C. Check Grafana Dashboards

- **Golden Signals Dashboard** (traffic, errors, latency, saturation)
- **K8s Dashboard** (pod status, CPU, memory)
- **PostgreSQL Dashboard** (connections, queries, replication lag)

##### D. Check Recent Changes

```bash
# Argo CD sync history
kubectl get applications -n argocd

# Recent deployments
kubectl rollout history deployment backend -n default

# Config changes (audit log)
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform -c \
  "SELECT * FROM config_history ORDER BY updated_at DESC LIMIT 10;"
```

---

### Phase 3: Mitigation (15-60 min)

#### SEV-1: PostgreSQL Down

**Symptoms:** API returns 503, logs show "connection refused"

**Fix:**
```bash
# Check pod status
kubectl get pods -n default -l app=postgresql

# If CrashLoopBackOff: Check logs
kubectl logs -n default postgresql-0 --tail=100

# Restart pod
kubectl delete pod postgresql-0 -n default

# If disk full:
kubectl exec -it postgresql-0 -n default -- df -h

# Clean up old WAL files
kubectl exec -it postgresql-0 -n default -- bash -c "rm -f /var/lib/postgresql/data/pg_wal/*.old"
```

**Escalation:** If restart fails → SEV-1 → Restore from backup (runbook: `sql-backup-restore.md`)

---

#### SEV-2: API Error Rate Spike

**Symptoms:** Grafana shows error rate >5%, users report 500 errors

**Fix:**
```bash
# Check backend logs
kubectl logs -n default -l app=backend --tail=100 | grep ERROR

# If database connection pool exhausted:
kubectl exec -it postgresql-0 -n default -- psql -U postgres -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='demo-platform';"

# Increase pool size (hot-reload config)
curl -X PUT https://api.platform.example.com/api/configs/db.pool_size \
  -H "Authorization: Bearer $JWT" \
  -d '{"value": "50"}'

# Or rollback recent deployment
kubectl rollout undo deployment backend -n default
```

---

#### SEV-3: Config Hot-Reload Slow

**Symptoms:** Config changes take >5 seconds to propagate

**Fix:** See [config-hot-reload.md](config-hot-reload.md)

---

### Phase 4: Communication (Ongoing)

#### Status Updates (Every 15 Minutes)

**Slack Template:**
```
🚨 SEV-1 Incident Update #3
Impact: PostgreSQL down, all users affected
Root Cause: Disk full (WAL files not archived)
Mitigation: Cleared old WAL files, pod restarted
Status: Monitoring (ETA: 10 min to full recovery)
Next Update: 14:45 UTC
```

#### External Communication (Status Page)

**Post public status update** (https://status.example.com):
```
🔴 Major Outage (2025-10-20 14:30 UTC)
We are investigating an issue with our database. All platform features are unavailable.
Next update: 14:45 UTC
```

---

### Phase 5: Resolution (60+ min)

#### Verify Fix

1. **Health checks pass**
   ```bash
   curl https://api.platform.example.com/health/ready
   ```

2. **Error rate back to baseline** (Grafana)
3. **User smoke tests** (create org, create project, chat action)

#### Close Incident

**Slack:**
```
✅ SEV-1 Incident Resolved
Duration: 45 minutes (14:30 - 15:15 UTC)
Root Cause: PostgreSQL disk full (WAL archiving failed)
Fix: Cleared old WAL files, increased disk size
Impact: All users affected for 45 minutes
Postmortem: https://docs.example.com/postmortems/2025-10-20
```

**PagerDuty:** Mark incident as "Resolved"

**Status Page:**
```
✅ Resolved (2025-10-20 15:15 UTC)
The database issue has been resolved. All services are operational.
```

---

## 3. Postmortem Process

### Timeline (Within 48 Hours)

1. **Draft postmortem** (incident owner)
2. **Review with team** (blameless)
3. **Publish postmortem** (Confluence/Wiki)
4. **Create action items** (Jira tickets)

---

### Postmortem Template

```markdown
# Postmortem: PostgreSQL Disk Full (2025-10-20)

## Incident Summary

**Date:** 2025-10-20 14:30 - 15:15 UTC (45 minutes)
**Severity:** SEV-1 (Complete outage)
**Impact:** All users unable to access platform
**Root Cause:** PostgreSQL disk full (WAL archiving failed)

---

## Timeline (All Times UTC)

| Time  | Event                                                  |
| ----- | ------------------------------------------------------ |
| 14:25 | WAL archiving job fails (S3 bucket unreachable)        |
| 14:30 | PostgreSQL disk reaches 100%                           |
| 14:30 | PostgreSQL crashes (no disk space)                     |
| 14:31 | PagerDuty alert sent to on-call                        |
| 14:32 | On-call acknowledges, opens war room                   |
| 14:35 | Investigation: Disk full identified                    |
| 14:40 | Mitigation: Old WAL files deleted                      |
| 14:42 | PostgreSQL pod restarted                               |
| 14:45 | Health checks pass                                     |
| 15:00 | User smoke tests pass                                  |
| 15:15 | Incident resolved                                      |

---

## Root Cause

1. **WAL archiving job failed** (S3 bucket temporarily unreachable)
2. **WAL files accumulated** (16MB every 5 minutes)
3. **Disk filled up** (10GB → 100% in 2 hours)
4. **PostgreSQL crashed** (no disk space to write)

---

## Impact

- **Users affected:** 100% (all users)
- **Duration:** 45 minutes
- **Data loss:** None (WAL files preserved, no data corruption)
- **Revenue impact:** $500 estimated (45 min downtime)

---

## What Went Well

✅ PagerDuty alert sent immediately (30 seconds)
✅ On-call responded within 2 minutes
✅ Root cause identified quickly (5 minutes)
✅ No data loss (WAL files preserved)

---

## What Went Wrong

❌ No disk space alerts (disk usage not monitored)
❌ WAL archiving failure not alerted
❌ No automatic cleanup of old WAL files

---

## Action Items

| ID  | Action                                          | Owner  | Due Date   | Priority |
| --- | ----------------------------------------------- | ------ | ---------- | -------- |
| 1   | Add disk usage alert (>80%)                     | SRE    | 2025-10-25 | P0       |
| 2   | Add WAL archiving failure alert                 | SRE    | 2025-10-25 | P0       |
| 3   | Implement auto-cleanup of old WAL files (>7d)   | Backend| 2025-10-30 | P1       |
| 4   | Increase disk size (10GB → 50GB)                | SRE    | 2025-10-22 | P1       |
| 5   | Test backup restore (quarterly drill)          | SRE    | 2025-11-01 | P2       |

---

## References

- [Runbook: SQL Backup & Restore](sql-backup-restore.md)
- [Incident Slack Thread](https://example.slack.com/archives/C123456/p1729512000)
- [Grafana Dashboard](https://grafana.example.com/d/postgresql)
```

---

## 4. Common Incidents

### A. PostgreSQL Down

**Symptoms:** API 503, "connection refused"
**Runbook:** [sql-backup-restore.md](sql-backup-restore.md)
**Quick Fix:**
```bash
kubectl delete pod postgresql-0 -n default
```

---

### B. Redis Down

**Symptoms:** Config hot-reload slow, chat broken
**Quick Fix:**
```bash
kubectl delete pod redis-0 -n default
```

**Fallback:** Reconcile loop fetches from PostgreSQL (10-min delay)

---

### C. API Error Rate Spike

**Symptoms:** Grafana shows errors >5%
**Quick Fix:**
```bash
# Rollback deployment
kubectl rollout undo deployment backend -n default
```

---

### D. TLS Certificate Expired

**Symptoms:** Browser shows "certificate expired", API unreachable
**Quick Fix:**
```bash
# Force cert renewal
kubectl delete certificate platform-tls -n default
kubectl apply -f infra/k8s/certificates/platform-tls.yaml
```

---

### E. Argo CD Sync Failed

**Symptoms:** Argo CD shows "OutOfSync", new deployments not applied
**Quick Fix:**
```bash
# Manual sync
argocd app sync backend --force
```

---

## 5. Escalation Matrix

| Severity  | Initial Response     | Escalate After | Escalate To              |
| --------- | -------------------- | -------------- | ------------------------ |
| **SEV-1** | On-Call (PagerDuty)  | 15 minutes     | Engineering Manager, CTO |
| **SEV-2** | On-Call (Slack)      | 1 hour         | Engineering Manager      |
| **SEV-3** | On-Call (Slack)      | 4 hours        | Team Lead                |
| **SEV-4** | Backlog (Jira)       | -              | -                        |

---

## 6. War Room Protocol

### Create War Room (Slack)

```
/incident start #incident-2025-10-20
```

**Channel name format:** `#incident-YYYY-MM-DD` (or `#incident-YYYY-MM-DD-N` if multiple)

### War Room Roles

| Role               | Responsibility                                  |
| ------------------ | ----------------------------------------------- |
| **Incident Lead**  | Coordinates response, makes decisions           |
| **Communicator**   | Posts status updates (Slack, status page)       |
| **Investigator**   | Debugs issue, proposes fixes                    |
| **Scribe**         | Documents timeline for postmortem               |

---

## 7. Status Page Updates

### Post Outage

```bash
# API call to status page (Atlassian Statuspage)
curl -X POST https://api.statuspage.io/v1/pages/abc123/incidents \
  -H "Authorization: OAuth $TOKEN" \
  -d '{
    "incident": {
      "name": "Database Outage",
      "status": "investigating",
      "impact_override": "critical",
      "body": "We are investigating a database issue. All features are unavailable."
    }
  }'
```

### Update Status

```bash
curl -X PATCH https://api.statuspage.io/v1/pages/abc123/incidents/xyz789 \
  -H "Authorization: OAuth $TOKEN" \
  -d '{
    "incident": {
      "status": "monitoring",
      "body": "Database issue resolved. Monitoring for stability."
    }
  }'
```

### Resolve Incident

```bash
curl -X PATCH https://api.statuspage.io/v1/pages/abc123/incidents/xyz789 \
  -H "Authorization: OAuth $TOKEN" \
  -d '{
    "incident": {
      "status": "resolved",
      "body": "All services are operational."
    }
  }'
```

---

## 8. Monitoring & Alerting

### Critical Alerts (SEV-1)

```yaml
# Prometheus alerts
alert: PostgreSQLDown
expr: pg_up == 0
for: 1m
severity: critical
annotations:
  summary: "PostgreSQL is down"
  runbook_url: "https://docs.example.com/runbooks/sql-backup-restore"

alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
for: 5m
severity: critical
annotations:
  summary: "API error rate >5%"
```

### Grafana Dashboards

- **Golden Signals** (traffic, errors, latency, saturation)
- **K8s Resources** (pod status, CPU, memory)
- **PostgreSQL** (connections, queries, replication lag)
- **Redis** (memory usage, commands/sec)

---

## 9. Checklist

### During Incident

- [ ] Acknowledge alert (PagerDuty)
- [ ] Create war room (Slack: `#incident-YYYY-MM-DD`)
- [ ] Post initial status (Slack + status page)
- [ ] Investigate (check pods, logs, Grafana)
- [ ] Mitigate (restart pods, rollback, config change)
- [ ] Update status every 15 minutes
- [ ] Verify fix (health checks, smoke tests)
- [ ] Resolve incident (PagerDuty + status page)

### After Incident

- [ ] Draft postmortem (within 24h)
- [ ] Review with team (blameless)
- [ ] Publish postmortem (Confluence/Wiki)
- [ ] Create action items (Jira)
- [ ] Update runbooks (if needed)

---

## References

- [Observability Strategy](../architecture/observability-strategy.md)
- [SQL Backup & Restore](sql-backup-restore.md)
- [Config Hot-Reload](config-hot-reload.md)
- [Secrets Rotation](secrets-rotation.md)
- [Google SRE Handbook](https://sre.google/sre-book/table-of-contents/)
