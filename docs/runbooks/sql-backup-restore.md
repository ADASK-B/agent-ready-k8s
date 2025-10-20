# Runbook: PostgreSQL Backup & Restore

> **Purpose:** Backup, restore, and disaster recovery procedures for PostgreSQL.
>
> **Audience:** SRE, Platform Engineers, On-Call
>
> **Related:** [ARCHITECTURE.md](../architecture/ARCHITECTURE.md), [observability-strategy.md](../architecture/observability-strategy.md)

---

## Overview

PostgreSQL is the **Source of Truth** for all application data (orgs, projects, configs, audit logs). Data retention: **12-36 months**.

**Backup Strategy:**
- **Nightly full backups** (pg_dump, encrypted, stored in S3/MinIO)
- **Continuous WAL archiving** (PITR = Point-In-Time Recovery)
- **12-36 month retention** (GDPR/compliance)
- **Monthly restore drills** (validate backups)

---

## 1. Backup Types

### A. Logical Backup (pg_dump)

**What:** SQL dump of database (schema + data)
**Frequency:** Nightly (2 AM UTC)
**Retention:** 36 months (compressed)
**Storage:** S3/MinIO bucket `postgresql-backups/`

**Pros:**
- ✅ Easy to restore (single SQL file)
- ✅ Portable (works across PostgreSQL versions)
- ✅ Selective restore (single table)

**Cons:**
- ⚠️ Slow for large databases (>100GB)
- ⚠️ No PITR (restore to specific timestamp)

---

### B. Physical Backup (WAL Archiving + PITR)

**What:** Continuous archiving of Write-Ahead Log (WAL) files
**Frequency:** Continuous (every 16MB WAL segment)
**Retention:** 7 days
**Storage:** S3/MinIO bucket `postgresql-wal/`

**Pros:**
- ✅ Point-In-Time Recovery (restore to any second)
- ✅ Fast restore (binary format)

**Cons:**
- ⚠️ Requires base backup + WAL files
- ⚠️ Same PostgreSQL version required

---

## 2. Nightly Backup (pg_dump)

### Automated Backup (K8s CronJob)

```yaml
# infra/k8s/cronjobs/postgresql-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-backup
  namespace: default
spec:
  schedule: "0 2 * * *"  # 2 AM UTC daily
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            env:
            - name: PGHOST
              value: "postgresql.default.svc.cluster.local"
            - name: PGDATABASE
              value: "demo-platform"
            - name: PGUSER
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-credentials
                  key: password
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: access_key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: secret_key
            command:
            - /bin/bash
            - -c
            - |
              set -e
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="/tmp/backup-${TIMESTAMP}.sql.gz"
              
              # pg_dump with compression
              pg_dump --verbose --clean --if-exists | gzip > $BACKUP_FILE
              
              # Upload to S3/MinIO
              apt-get update && apt-get install -y awscli
              aws s3 cp $BACKUP_FILE s3://postgresql-backups/$(date +%Y)/$(date +%m)/ \
                --endpoint-url https://minio.example.com
              
              # Log success
              echo "Backup completed: $BACKUP_FILE"
          restartPolicy: OnFailure
```

### Manual Backup (On-Demand)

```bash
# SSH into PostgreSQL pod
kubectl exec -it postgresql-0 -n default -- bash

# Create backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump -U postgres -d demo-platform --clean --if-exists | gzip > /tmp/backup-${TIMESTAMP}.sql.gz

# Upload to S3 (if MinIO available)
aws s3 cp /tmp/backup-${TIMESTAMP}.sql.gz s3://postgresql-backups/ \
  --endpoint-url https://minio.example.com
```

---

## 3. WAL Archiving (PITR)

### Enable WAL Archiving

```sql
-- PostgreSQL config (postgresql.conf)
wal_level = replica
archive_mode = on
archive_command = 'aws s3 cp %p s3://postgresql-wal/%f --endpoint-url https://minio.example.com'
archive_timeout = 300  # Archive every 5 minutes
```

### Test WAL Archiving

```bash
# Force log switch
kubectl exec -it postgresql-0 -n default -- psql -U postgres -c "SELECT pg_switch_wal();"

# Check S3 bucket
aws s3 ls s3://postgresql-wal/ --endpoint-url https://minio.example.com
```

---

## 4. Restore Procedures

### A. Restore from pg_dump (Logical Backup)

#### 1. Download Backup

```bash
# List backups
aws s3 ls s3://postgresql-backups/2025/10/ --endpoint-url https://minio.example.com

# Download specific backup
aws s3 cp s3://postgresql-backups/2025/10/backup-20251020_020000.sql.gz /tmp/ \
  --endpoint-url https://minio.example.com
```

#### 2. Stop Application (Prevent Writes)

```bash
# Scale backend to 0 replicas
kubectl scale deployment backend -n default --replicas=0

# Verify no connections
kubectl exec -it postgresql-0 -n default -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname='demo-platform';"
```

#### 3. Drop & Recreate Database

```bash
kubectl exec -it postgresql-0 -n default -- bash

# Drop database (WARNING: ALL DATA LOST)
psql -U postgres -c "DROP DATABASE IF EXISTS \"demo-platform\";"
psql -U postgres -c "CREATE DATABASE \"demo-platform\";"
```

#### 4. Restore Backup

```bash
# Decompress and restore
gunzip -c /tmp/backup-20251020_020000.sql.gz | psql -U postgres -d demo-platform

# Check row counts
psql -U postgres -d demo-platform -c "SELECT 'organizations', count(*) FROM organizations UNION ALL SELECT 'projects', count(*) FROM projects;"
```

#### 5. Restart Application

```bash
# Scale backend back up
kubectl scale deployment backend -n default --replicas=3

# Verify health
kubectl get pods -n default
curl https://api.platform.example.com/health/ready
```

---

### B. Restore from WAL (PITR)

#### 1. Create Base Backup

```bash
# On PostgreSQL primary
pg_basebackup -U postgres -D /tmp/base_backup -Ft -Xs -P
```

#### 2. Stop PostgreSQL

```bash
kubectl scale statefulset postgresql -n default --replicas=0
```

#### 3. Restore Base Backup

```bash
# Extract base backup
tar -xf /tmp/base_backup/base.tar -C /var/lib/postgresql/data
tar -xf /tmp/base_backup/pg_wal.tar -C /var/lib/postgresql/data/pg_wal
```

#### 4. Configure Recovery

```bash
# Create recovery.conf (PostgreSQL 12+: recovery.signal)
cat > /var/lib/postgresql/data/recovery.signal <<EOF
restore_command = 'aws s3 cp s3://postgresql-wal/%f %p --endpoint-url https://minio.example.com'
recovery_target_time = '2025-10-20 14:30:00'  # PITR target
EOF
```

#### 5. Start PostgreSQL

```bash
kubectl scale statefulset postgresql -n default --replicas=1

# Monitor recovery
kubectl logs -f postgresql-0 -n default | grep recovery
```

---

## 5. Restore Drills (Monthly)

### Purpose

Validate backups are restorable (avoid "backup worked, restore didn't" disasters).

### Schedule

**Monthly:** First Saturday, 10 AM UTC

### Procedure

1. **Provision test environment** (separate K8s namespace)
2. **Download latest backup** from S3
3. **Restore to test DB**
4. **Run smoke tests** (check row counts, query performance)
5. **Destroy test environment**
6. **Document results** (Confluence/Wiki)

### Automation (Test Restore CronJob)

```yaml
# infra/k8s/cronjobs/postgresql-restore-drill.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-restore-drill
  namespace: default
spec:
  schedule: "0 10 1 * 6"  # First Saturday, 10 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: restore-drill
            image: postgres:16
            command:
            - /bin/bash
            - -c
            - |
              # Download latest backup
              aws s3 cp s3://postgresql-backups/$(date +%Y)/$(date +%m)/ /tmp/ \
                --recursive --endpoint-url https://minio.example.com
              
              # Restore to test DB
              LATEST_BACKUP=$(ls -t /tmp/*.sql.gz | head -1)
              gunzip -c $LATEST_BACKUP | psql -U postgres -d test_restore
              
              # Verify row counts
              psql -U postgres -d test_restore -c "SELECT 'organizations', count(*) FROM organizations;"
              
              # Drop test DB
              psql -U postgres -c "DROP DATABASE test_restore;"
```

---

## 6. Disaster Recovery Scenarios

### Scenario 1: Accidental DELETE

**Symptom:** "All organizations deleted!"
**Cause:** Accidental `DELETE FROM organizations;`

**Recovery:**
1. **Stop application immediately** (prevent more writes)
2. **Identify deletion time** (check audit logs: `config_history` table)
3. **PITR restore** to 1 minute before deletion
4. **Verify data** (check row counts)
5. **Restart application**

**Timeline:** 15-30 minutes

---

### Scenario 2: Database Corruption

**Symptom:** PostgreSQL crashes, logs show "corrupted page"
**Cause:** Disk failure, bit rot, bug

**Recovery:**
1. **Stop PostgreSQL**
2. **Restore from latest pg_dump**
3. **Replay WAL files** (if PITR enabled)
4. **Verify data integrity** (check constraints, foreign keys)
5. **Restart application**

**Timeline:** 1-2 hours

---

### Scenario 3: Datacenter Failure

**Symptom:** Entire K8s cluster unreachable
**Cause:** Cloud region outage, network partition

**Recovery:**
1. **Provision new K8s cluster** (different region)
2. **Deploy PostgreSQL**
3. **Download latest backup** from S3 (in different region)
4. **Restore database**
5. **Deploy application**
6. **Update DNS** (point to new cluster)

**Timeline:** 2-4 hours (depends on cluster provisioning)

---

## 7. Monitoring

### Backup Success Metrics

```yaml
# Prometheus metrics
postgresql_backup_last_success_timestamp  # Unix timestamp
postgresql_backup_duration_seconds        # Backup duration
postgresql_backup_size_bytes              # Backup file size
```

### Alerts

```yaml
alert: BackupFailed
expr: time() - postgresql_backup_last_success_timestamp > 86400 * 2  # No backup in 48h
for: 1h
severity: critical

alert: BackupSlow
expr: postgresql_backup_duration_seconds > 3600  # Backup takes >1 hour
for: 5m
severity: warning
```

### Logs

```bash
# Check CronJob logs
kubectl logs -n default $(kubectl get pods -n default -l job-name=postgresql-backup -o name | tail -1)

# Check S3 uploads
aws s3 ls s3://postgresql-backups/ --recursive --endpoint-url https://minio.example.com
```

---

## 8. Troubleshooting

### "Backup CronJob failed"

**Symptoms:** CronJob pod shows `Error` status
**Debug:**
```bash
kubectl describe cronjob postgresql-backup -n default
kubectl logs -n default $(kubectl get pods -n default -l job-name=postgresql-backup -o name | tail -1)
```

**Common causes:**
- **Wrong credentials** (PGPASSWORD, AWS_ACCESS_KEY_ID)
- **S3 bucket doesn't exist**
- **Network timeout** (large backup)

---

### "Restore hangs"

**Symptoms:** `psql` restore command runs for hours
**Causes:**
- **Large backup** (>100GB)
- **Slow disk I/O**
- **Foreign key constraints** (disable during restore)

**Fix:**
```sql
-- Disable triggers/constraints during restore
SET session_replication_role = replica;

-- After restore
SET session_replication_role = DEFAULT;
```

---

### "PITR recovery stuck"

**Symptoms:** PostgreSQL logs show "waiting for WAL segment"
**Causes:**
- **Missing WAL files** in S3
- **Wrong restore_command**

**Fix:**
```bash
# List available WAL files
aws s3 ls s3://postgresql-wal/ --endpoint-url https://minio.example.com

# Check recovery.signal
cat /var/lib/postgresql/data/recovery.signal
```

---

## 9. Retention Policy

| Backup Type       | Retention | Storage          |
| ----------------- | --------- | ---------------- |
| Nightly pg_dump   | 36 months | S3 Glacier       |
| WAL files (PITR)  | 7 days    | S3 Standard      |
| Monthly snapshots | 36 months | S3 Standard-IA   |

### Lifecycle Policy (S3)

```json
{
  "Rules": [
    {
      "Id": "Move old backups to Glacier",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 1095
      }
    }
  ]
}
```

---

## 10. Checklist

### Before Restore

- [ ] Stop application (scale to 0 replicas)
- [ ] Notify team (Slack/PagerDuty)
- [ ] Download backup from S3
- [ ] Verify backup integrity (gunzip -t)
- [ ] Create snapshot of current DB (if possible)

### After Restore

- [ ] Verify row counts (organizations, projects)
- [ ] Run smoke tests (API health checks)
- [ ] Check audit logs (config_history)
- [ ] Restart application (scale up replicas)
- [ ] Monitor error rates (Grafana)
- [ ] Document incident (postmortem)

---

## References

- [PostgreSQL Backup & Restore](https://www.postgresql.org/docs/current/backup.html)
- [pg_dump Documentation](https://www.postgresql.org/docs/current/app-pgdump.html)
- [WAL Archiving](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [PITR Recovery](https://www.postgresql.org/docs/current/continuous-archiving.html#BACKUP-PITR-RECOVERY)
