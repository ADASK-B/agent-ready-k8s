# Observability Strategy

> **Status:** Draft - needs content
> **Owner:** SRE Team
> **Last Updated:** 20 October 2025

## Overview

This document defines the observability stack, metrics catalog, logging strategy, tracing approach, and SLO definitions for the platform.

## Table of Contents

- [Observability Pillars](#observability-pillars)
- [Metrics Strategy](#metrics-strategy)
- [Logging Strategy](#logging-strategy)
- [Tracing Strategy](#tracing-strategy)
- [Dashboards](#dashboards)
- [Alerting](#alerting)
- [SLOs & SLIs](#slos--slis)

---

## Observability Pillars

### The Three Pillars

1. **Metrics** - What is happening? (Prometheus)
2. **Logs** - Why is it happening? (Loki)
3. **Traces** - How is it happening? (Tempo)

### Correlation

- Unified labels across all pillars
- Trace ID propagation (W3C Trace Context)
- Exemplars linking metrics → traces

---

## Metrics Strategy

### Stack

- **Prometheus** - Metrics collection & storage (15 days retention)
- **Grafana** - Visualization & dashboards
- **Alertmanager** - Alert routing & notification
- **Optional:** Mimir/Thanos for long-term storage

### Golden Signals (RED Method)

| Signal | Metric | Target |
|--------|--------|--------|
| **Rate** | Requests per second | - |
| **Errors** | Error rate (%) | < 1% |
| **Duration** | P50, P95, P99 latency | P95 < 500ms |

### Platform Metrics Catalog

#### Kubernetes Core

- [ ] `kube_pod_status_phase` - Pod health
- [ ] `kube_node_status_condition` - Node health
- [ ] `kube_deployment_status_replicas` - Deployment replicas
- [ ] `kube_persistentvolumeclaim_status_phase` - PVC status

#### Application Metrics

- [ ] `http_requests_total` - Total requests
- [ ] `http_request_duration_seconds` - Request latency
- [ ] `http_requests_failed_total` - Failed requests
- [ ] `db_connection_pool_size` - Database connections

#### Business Metrics

- [ ] `organizations_total` - Active organizations
- [ ] `projects_total` - Active projects
- [ ] `chat_actions_total` - Chat actions performed
- [ ] `config_hot_reload_duration_seconds` - Hot-reload latency

---

## Logging Strategy

### Stack

- **Loki** - Log aggregation & storage
- **Promtail** - Log collection agent
- **Grafana** - Log exploration

### Log Levels

| Level | When to Use | Examples |
|-------|-------------|----------|
| **ERROR** | Application errors | Exceptions, failures |
| **WARN** | Potential issues | Retries, degraded state |
| **INFO** | Normal operations | Startup, config changes |
| **DEBUG** | Development only | Detailed flow, variables |

### Structured Logging

```json
{
  "timestamp": "2025-10-20T10:30:00Z",
  "level": "INFO",
  "service": "backend",
  "trace_id": "abc123...",
  "org_id": "123",
  "message": "Organization created"
}
```

### Log Retention

- **Production:** 30 days (hot storage)
- **Stage:** 7 days
- **Audit Logs:** 90 days (cold storage)

### Redaction Rules

- [ ] No PII (names, emails, addresses)
- [ ] No passwords or tokens
- [ ] No credit card numbers
- [ ] Use correlation IDs instead

---

## Tracing Strategy

### Stack

- **Tempo** - Distributed tracing backend
- **OpenTelemetry Collector** - Trace collection
- **Grafana** - Trace visualization

### Trace Propagation

```
User → Frontend → Backend → PostgreSQL
  └─────────────┬─────────────┘
          trace_id: abc123...
```

### Span Attributes

- [ ] `service.name` - Service identifier
- [ ] `http.method` - HTTP method
- [ ] `http.status_code` - Response status
- [ ] `db.statement` - SQL query
- [ ] `org_id` - Tenant identifier

### Sampling Strategy

- **Production:** 10% sampling (reduce volume)
- **Stage/Dev:** 100% sampling

---

## Dashboards

### Standard Dashboards

| Dashboard | Purpose | Owner |
|-----------|---------|-------|
| **Golden Signals** | RED metrics (Rate, Errors, Duration) | SRE |
| **Kubernetes Overview** | Cluster health, node status | SRE |
| **PostgreSQL** | Database metrics, connections, queries | DBA |
| **Redis** | Cache hit rate, memory usage | SRE |
| **Business Metrics** | Orgs, Projects, Chat actions | Product |
| **SLO Burn Rate** | Error budget tracking | SRE |
| **Certificate Expiry** | TLS cert expiration tracking | Security |

### Dashboard Standards

- [ ] Consistent labels and filters
- [ ] Time range selector (last 1h, 6h, 24h, 7d)
- [ ] Drill-down links (metrics → logs → traces)
- [ ] Annotations for deployments

---

## Alerting

### Alert Routing

```
Prometheus → Alertmanager → PagerDuty/Slack/Email
```

### Alert Severity

| Severity | Response | Examples |
|----------|----------|----------|
| **Critical** | Page on-call | API down, database down |
| **Warning** | Ticket | High error rate, disk 80% full |
| **Info** | Log only | Deployment completed |

### Alert Rules (Examples)

#### High Error Rate
```yaml
alert: HighErrorRate
expr: rate(http_requests_failed_total[5m]) > 0.05
for: 5m
severity: warning
```

#### API Down
```yaml
alert: APIDown
expr: up{job="backend"} == 0
for: 1m
severity: critical
```

#### Certificate Expiry
```yaml
alert: CertificateExpiringSoon
expr: (cert_manager_certificate_expiration_timestamp_seconds - time()) < 14 * 24 * 3600
severity: warning
```

---

## SLOs & SLIs

### Service Level Indicators (SLIs)

| SLI | Target | Measurement |
|-----|--------|-------------|
| **Availability** | 99.9% | Uptime (successful requests) |
| **Latency** | P95 < 500ms | Request duration |
| **Error Rate** | < 1% | Failed requests / total requests |

### Service Level Objectives (SLOs)

#### API Availability
- **Target:** 99.9% (monthly)
- **Error Budget:** 0.1% = ~43 minutes downtime/month

#### API Latency
- **Target:** P95 < 500ms, P99 < 1s
- **Measurement:** 5-minute rolling window

#### Hot-Reload Latency
- **Target:** P95 < 100ms (config update → pod applies)
- **Measurement:** `config_hot_reload_duration_seconds`

### Error Budget Policy

- **100% budget:** Deploy anytime
- **75% budget:** Slow down deployments
- **50% budget:** Feature freeze, focus on reliability
- **0% budget:** No deploys until budget restored

---

## Monitoring Costs

### Retention Trade-offs

| Component | Retention | Cost Impact |
|-----------|-----------|-------------|
| Metrics | 15 days | Low (TSDB efficient) |
| Logs | 30 days | Medium (verbose) |
| Traces | 3 days | Low (sampled) |

### Optimization

- [ ] Log volume reduction (debug → info)
- [ ] Trace sampling (10% in prod)
- [ ] Metric cardinality limits
- [ ] Aggregation for long-term storage (Mimir)

---

## References

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [SRE Workbook - SLOs](https://sre.google/workbook/implementing-slos/)
