# Runbook: Secrets Rotation

> **Purpose:** Rotate secrets (DB passwords, Redis ACL, JWT keys, TLS certs) without downtime.
>
> **Audience:** SRE, Security Team, Platform Engineers
>
> **Related:** [SECURITY.md](../../SECURITY.md), [ADR-0004 Guest Auth](../adr/ADR-0004-guest-auth.md)

---

## Overview

**Secrets to Rotate:**
1. **PostgreSQL Password** (90-day rotation)
2. **Redis ACL Password** (90-day rotation)
3. **JWT Signing Key** (90-day rotation)
4. **TLS Certificates** (cert-manager auto-renewal, 60 days before expiry)
5. **External Secrets (KMS)** (on-demand rotation)

**Rotation Schedule:**
- **Automated:** TLS certs (cert-manager)
- **Manual:** DB passwords, JWT keys (runbook)
- **On-Demand:** After security incident

---

## 1. PostgreSQL Password Rotation

### Strategy

Use **dual-password** approach (zero downtime):
1. Create **new user** with new password
2. Update application to use **new user**
3. Delete **old user**

---

### Step-by-Step Procedure

#### 1. Generate New Password

```bash
# Generate random password (32 chars)
NEW_PASSWORD=$(openssl rand -base64 32)
echo $NEW_PASSWORD
```

#### 2. Create New PostgreSQL User

```bash
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform

-- Create new user
CREATE USER backend_v2 WITH PASSWORD '<NEW_PASSWORD>';

-- Grant same permissions as old user
GRANT ALL PRIVILEGES ON DATABASE "demo-platform" TO backend_v2;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO backend_v2;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO backend_v2;

-- Verify
\du backend_v2
```

#### 3. Update K8s Secret

```bash
# Update secret (new username + password)
kubectl create secret generic postgresql-credentials \
  --from-literal=username=backend_v2 \
  --from-literal=password=$NEW_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify
kubectl get secret postgresql-credentials -o jsonpath='{.data.username}' | base64 -d
```

#### 4. Rolling Restart Backend Pods

```bash
# Restart backend (picks up new secret)
kubectl rollout restart deployment backend -n default

# Watch rollout
kubectl rollout status deployment backend -n default

# Verify health
kubectl get pods -n default -l app=backend
curl https://api.platform.example.com/health/ready
```

#### 5. Delete Old User

```bash
# Wait 10 minutes (ensure all pods restarted)
sleep 600

# Delete old user
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform

DROP USER backend;

-- Verify
\du
```

---

### Automation (Quarterly Rotation)

```yaml
# tools/scripts/rotate-postgresql-password.sh
#!/bin/bash
set -e

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)
NEW_USER="backend_$(date +%Y%m%d)"

# Create new user
kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform -c "
  CREATE USER $NEW_USER WITH PASSWORD '$NEW_PASSWORD';
  GRANT ALL PRIVILEGES ON DATABASE \"demo-platform\" TO $NEW_USER;
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $NEW_USER;
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $NEW_USER;
"

# Update secret
kubectl create secret generic postgresql-credentials \
  --from-literal=username=$NEW_USER \
  --from-literal=password=$NEW_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart backend
kubectl rollout restart deployment backend -n default
kubectl rollout status deployment backend -n default

echo "Password rotated successfully"
echo "OLD_USER=$(kubectl exec -it postgresql-0 -n default -- psql -U postgres -d demo-platform -c '\du' | grep backend | awk '{print $1}')"
echo "NEW_USER=$NEW_USER"
```

---

## 2. Redis ACL Password Rotation

### Strategy

Redis supports **ACL user management** (Redis 6+):
1. Create **new ACL user** with new password
2. Update application to use **new user**
3. Delete **old user**

---

### Step-by-Step Procedure

#### 1. Generate New Password

```bash
NEW_REDIS_PASSWORD=$(openssl rand -base64 32)
echo $NEW_REDIS_PASSWORD
```

#### 2. Create New Redis ACL User

```bash
kubectl exec -it redis-0 -n default -- redis-cli

# Create new user (subscribe-only permission)
ACL SETUSER backend_v2 on >$NEW_REDIS_PASSWORD ~config:* +subscribe -@all

# Verify
ACL LIST
# Should show: user backend_v2 on ~config:* +subscribe -@all
```

#### 3. Update K8s Secret

```bash
kubectl create secret generic redis-credentials \
  --from-literal=username=backend_v2 \
  --from-literal=password=$NEW_REDIS_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 4. Rolling Restart Backend Pods

```bash
kubectl rollout restart deployment backend -n default
kubectl rollout status deployment backend -n default
```

#### 5. Delete Old User

```bash
kubectl exec -it redis-0 -n default -- redis-cli

ACL DELUSER backend

# Verify
ACL LIST
```

---

## 3. JWT Signing Key Rotation

### Strategy

Use **key versioning** (graceful rotation):
1. Add **new key** to backend (supports both old + new keys)
2. Issue **new JWTs** with new key
3. Remove **old key** after all old JWTs expire (15 min TTL)

---

### Step-by-Step Procedure

#### 1. Generate New JWT Key

```bash
NEW_JWT_SECRET=$(openssl rand -base64 64)
echo $NEW_JWT_SECRET
```

#### 2. Update K8s Secret (Add New Key)

```bash
# Multi-key support (backend validates both keys)
kubectl create secret generic jwt-keys \
  --from-literal=jwt-secret-v1=$OLD_JWT_SECRET \
  --from-literal=jwt-secret-v2=$NEW_JWT_SECRET \
  --from-literal=active-key=jwt-secret-v2 \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 3. Update Backend Code (Support Multi-Keys)

```python
# backend/auth.py
import os

JWT_KEYS = {
    "v1": os.environ["JWT_SECRET_V1"],
    "v2": os.environ["JWT_SECRET_V2"],
}
ACTIVE_KEY = os.environ["ACTIVE_KEY"]  # "jwt-secret-v2"

def create_jwt(payload):
    """Issue JWT with active key (v2)"""
    return jwt.encode(payload, JWT_KEYS[ACTIVE_KEY], algorithm="HS256")

def validate_jwt(token):
    """Validate JWT with any key (v1 or v2)"""
    for key_version, secret in JWT_KEYS.items():
        try:
            return jwt.decode(token, secret, algorithms=["HS256"])
        except jwt.InvalidSignatureError:
            continue
    raise jwt.InvalidSignatureError("Invalid token")
```

#### 4. Rolling Restart Backend

```bash
kubectl rollout restart deployment backend -n default
kubectl rollout status deployment backend -n default
```

#### 5. Remove Old Key (After 15 Minutes)

```bash
# Wait for all old JWTs to expire (TTL = 15 min)
sleep 900

# Remove old key
kubectl create secret generic jwt-keys \
  --from-literal=jwt-secret-v2=$NEW_JWT_SECRET \
  --from-literal=active-key=jwt-secret-v2 \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart backend
kubectl rollout restart deployment backend -n default
```

---

## 4. TLS Certificate Rotation (Automated)

### Strategy

**cert-manager** auto-renews certs **60 days before expiry**.

---

### Verification

```bash
# Check cert expiry
kubectl get certificate -n default

# Output:
# NAME               READY   SECRET             AGE
# platform-tls-cert  True    platform-tls       30d
```

### Manual Renewal (If Needed)

```bash
# Force cert renewal
kubectl delete secret platform-tls -n default
kubectl delete certificate platform-tls -n default

# Recreate certificate
kubectl apply -f infra/k8s/certificates/platform-tls.yaml

# Verify
kubectl get certificate -n default
```

---

## 5. External Secrets (KMS)

### Strategy

Use **External Secrets Operator (ESO)** to fetch secrets from KMS.

---

### Rotation Procedure

#### 1. Update Secret in KMS

```bash
# AWS Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id postgresql-password \
  --secret-string $NEW_PASSWORD

# Or: AWS KMS (rotate data key)
aws kms create-data-key --key-id alias/platform-secrets
```

#### 2. Refresh ESO (Sync Interval = 5 min)

```bash
# ESO auto-syncs every 5 minutes
# Or force sync:
kubectl annotate externalsecret postgresql-credentials \
  force-sync="$(date +%s)" -n default
```

#### 3. Verify Secret Updated

```bash
kubectl get secret postgresql-credentials -o jsonpath='{.data.password}' | base64 -d
```

---

## 6. Monitoring

### Metrics (Prometheus)

```yaml
# Secret age (days since creation)
secret_age_days{secret_name, namespace}

# Cert expiry (days until expiration)
certmanager_certificate_expiration_timestamp_seconds{name, namespace}
```

### Alerts

```yaml
alert: SecretExpiringSoon
expr: secret_age_days > 80  # 90-day rotation policy
for: 1d
severity: warning
annotations:
  summary: "Secret {{ $labels.secret_name }} is >80 days old (rotation due)"

alert: TLSCertExpiringSoon
expr: (certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 30
for: 1d
severity: critical
annotations:
  summary: "TLS cert {{ $labels.name }} expires in <30 days"
```

---

## 7. Rotation Schedule

| Secret                | Rotation Interval | Automation       | Owner         |
| --------------------- | ----------------- | ---------------- | ------------- |
| PostgreSQL Password   | 90 days           | Manual (runbook) | SRE           |
| Redis ACL Password    | 90 days           | Manual (runbook) | SRE           |
| JWT Signing Key       | 90 days           | Manual (runbook) | Security Team |
| TLS Certificates      | Auto-renewal      | cert-manager     | cert-manager  |
| KMS Data Keys         | 365 days          | AWS KMS          | Security Team |

---

## 8. Emergency Rotation (Security Incident)

### Scenario: JWT Key Compromised

**Symptom:** Attacker has stolen JWT signing key
**Urgency:** Immediate (1 hour)

**Procedure:**

#### 1. Generate New Key Immediately

```bash
NEW_JWT_SECRET=$(openssl rand -base64 64)
```

#### 2. Update Secret (Single Key Only)

```bash
# Remove old key immediately (don't support multi-keys)
kubectl create secret generic jwt-keys \
  --from-literal=jwt-secret=$NEW_JWT_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### 3. Restart Backend (Emergency Rollout)

```bash
kubectl rollout restart deployment backend -n default
kubectl rollout status deployment backend -n default --timeout=5m
```

#### 4. Revoke All JWTs (JTI Denylist)

```bash
# Add all active JWTs to Redis denylist
kubectl exec -it redis-0 -n default -- redis-cli FLUSHDB
```

#### 5. Force All Users to Re-Authenticate

**Impact:** All users logged out, must sign in again.

---

## 9. Troubleshooting

### "Backend can't connect to PostgreSQL after rotation"

**Cause:** Backend still using old username/password
**Debug:**
```bash
# Check backend logs
kubectl logs -n default -l app=backend --tail=100 | grep "password authentication failed"

# Verify secret updated
kubectl get secret postgresql-credentials -o jsonpath='{.data.username}' | base64 -d
```

**Fix:**
```bash
# Force pod restart (reload secret)
kubectl delete pod -n default -l app=backend
```

---

### "cert-manager not renewing cert"

**Cause:** cert-manager CRD issue, ACME challenge failed
**Debug:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate platform-tls -n default
```

**Fix:**
```bash
# Recreate certificate
kubectl delete certificate platform-tls -n default
kubectl apply -f infra/k8s/certificates/platform-tls.yaml
```

---

## 10. Checklist

### Before Rotation

- [ ] Generate new secret (password/key)
- [ ] Verify backup exists (in case rollback needed)
- [ ] Schedule maintenance window (low-traffic period)
- [ ] Notify team (Slack/PagerDuty)

### During Rotation

- [ ] Create new user/key
- [ ] Update K8s secret
- [ ] Rolling restart pods
- [ ] Verify health checks pass
- [ ] Monitor error rates (Grafana)

### After Rotation

- [ ] Delete old user/key (after grace period)
- [ ] Verify no errors in logs
- [ ] Document rotation (date, version)
- [ ] Update runbook (if process changed)

---

## References

- [PostgreSQL User Management](https://www.postgresql.org/docs/current/user-manag.html)
- [Redis ACL](https://redis.io/docs/management/security/acl/)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [External Secrets Operator](https://external-secrets.io/)
