# ADR-0001: Config Source of Truth = PostgreSQL (not etcd)

> **Status:** Accepted
> **Date:** 20 October 2025
> **Deciders:** Platform Team, Backend Team
> **Related:** ADR-0002 (Hot-Reload), ADR-0003 (etcd Scope)

## Context

We need a reliable, auditable, and queryable store for application configuration (AI thresholds, feature flags, email settings, webhooks, quotas). Config changes must be:

1. **Persistent** (survive restarts)
2. **Auditable** (who changed what when)
3. **Queryable** (SQL for reports/analytics)
4. **Portable** (no vendor lock-in)
5. **Hot-reloadable** (without pod restarts)

### Options Considered

1. **PostgreSQL** (relational database)
2. **etcd** (K8s control plane store)
3. **ConfigMaps** (K8s native config)
4. **Redis** (in-memory key-value store)

---

## Decision

**We will use PostgreSQL as the Source of Truth for application configuration.**

### Rationale

#### Why PostgreSQL?

✅ **SQL Queries** - Complex queries, JOINs, aggregations for reporting
✅ **ACID Transactions** - Strong consistency guarantees
✅ **Audit Trail** - `config_history` table with full change log
✅ **Backup/Restore** - Proven tools (pg_dump, PITR)
✅ **Portability** - Works everywhere (local, cloud, on-prem)
✅ **Mature Tooling** - ORMs, admin UIs, monitoring tools
✅ **Row-Level Security** - Tenant isolation via RLS
✅ **Temporal Queries** - Query config state at any point in time

#### Why NOT etcd?

❌ **No SQL** - Key-value only, no JOINs or aggregations
❌ **1.5 MB Limit** - Hard limit per key
❌ **Vendor Lock-In** - K8s-specific, not portable
❌ **Complex Access** - Requires K8s API access, mTLS setup
❌ **No Audit Trail** - No built-in change history
❌ **Backup Complexity** - Must backup entire cluster

#### Why NOT ConfigMaps?

❌ **Pod Restart Required** - No hot-reload (must restart pods)
❌ **No Audit Trail** - Git history only (not runtime changes)
❌ **No Query Capability** - Cannot query config values via API
❌ **No Strong Consistency** - Eventual consistency issues

#### Why NOT Redis (as SoT)?

❌ **Not Persistent** - Data lost on restart (unless AOF/RDB enabled)
❌ **No ACID** - No transactions, no consistency guarantees
❌ **No SQL** - Key-value only

---

## Consequences

### Positive

- ✅ **Reliable Audit Trail** - Full change history (who, when, old, new, why)
- ✅ **SQL Reporting** - Easy to generate config reports/analytics
- ✅ **Tenant Isolation** - RLS ensures orgs only see their configs
- ✅ **Portable** - Works on any PostgreSQL (local, cloud, managed)
- ✅ **Mature Ecosystem** - ORMs, migration tools, admin UIs

### Negative

- ⚠️ **Not Real-Time** - Polling DB for changes = 5s delay (mitigated by ADR-0002: Redis Pub/Sub)
- ⚠️ **DB Load** - Frequent config reads (mitigated by in-memory caching + hot-reload)

### Risks

- **Risk 1:** DB unavailable = config changes blocked
  - **Mitigation:** HA PostgreSQL (replication), pods cache last-known config in memory
- **Risk 2:** Schema migrations breaking configs
  - **Mitigation:** Backward-compatible migrations, feature flags for rollout

---

## Schema Design

### `service_configs` Table

```sql
CREATE TABLE service_configs (
    id SERIAL PRIMARY KEY,
    org_id INT NOT NULL REFERENCES organizations(id),
    service VARCHAR(50) NOT NULL,  -- 'ai', 'email', 'api', 'features'
    key VARCHAR(100) NOT NULL,     -- 'threshold', 'max_retries', 'dark_mode'
    value TEXT NOT NULL,           -- '0.9', '5', 'true'
    version INT NOT NULL DEFAULT 1, -- Monotonic version for hot-reload
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, service, key)
);

CREATE INDEX idx_service_configs_lookup ON service_configs(org_id, service, key);
```

### `config_history` Table (Audit Log)

```sql
CREATE TABLE config_history (
    id SERIAL PRIMARY KEY,
    config_id INT NOT NULL REFERENCES service_configs(id),
    old_value TEXT,
    new_value TEXT NOT NULL,
    changed_by VARCHAR(255) NOT NULL,  -- User ID or service account
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT  -- Optional: why was this changed?
);

CREATE INDEX idx_config_history_lookup ON config_history(config_id, changed_at DESC);
```

---

## Integration with Hot-Reload

**See ADR-0002** for hot-reload mechanism (Redis Pub/Sub).

**Flow:**
1. User updates config → Backend writes to PostgreSQL
2. Backend publishes event to Redis Pub/Sub
3. All pods receive event → fetch new value from PostgreSQL
4. Pods update in-memory config (no restart)

**PostgreSQL = Source of Truth (persistent, auditable)**
**Redis = Event Channel (real-time notifications)**

---

## Alternatives Rejected

### Option 1: etcd for App Config

**Rejected because:**
- Too complex for app-level config
- Vendor lock-in to Kubernetes
- No SQL, no audit trail
- 1.5 MB limit per key

**When to use etcd:**
- K8s control plane only (namespaces, pods, services)
- Distributed coordination (leader election, locks)
- Not for application configuration

### Option 2: ConfigMaps Only

**Rejected because:**
- Requires pod restart for config changes
- No hot-reload capability
- No runtime audit trail

**When to use ConfigMaps:**
- Static config (rarely changes)
- Non-sensitive data
- OK with pod restarts

---

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PITR Backup](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [Row-Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- ADR-0002: Hot-Reload via Redis Pub/Sub
- ADR-0003: etcd Scope (K8s Control Plane Only)
