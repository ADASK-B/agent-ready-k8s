---
name: observability-engineer
description: Design and implement observability stack with metrics, logs, and traces. Use for Prometheus, Grafana, Loki, Tempo, OpenTelemetry, alerting, and SLO/SLI design. Keywords: observability, monitoring, tracing, Prometheus, Grafana, Loki, Tempo, OpenTelemetry, OTEL, alerting, SLO, SLI.
---

# Observability Engineer

Expert in designing and implementing comprehensive observability solutions for Kubernetes environments. Covers the three pillars: metrics, logs, and traces.

## When to Use This Skill

- Setting up Prometheus metrics collection
- Configuring Grafana dashboards and visualizations
- Implementing centralized logging with Loki
- Setting up distributed tracing with Tempo/Jaeger
- Instrumenting applications with OpenTelemetry
- Designing SLOs and SLIs
- Configuring alerting and on-call integrations
- Debugging performance issues with observability data

---

## The Three Pillars of Observability

```
┌─────────────────────────────────────────────────────────┐
│                      Grafana UI                         │
│   (Unified visualization for all observability data)    │
└─────────────────────────────────────────────────────────┘
         │              │               │
         ▼              ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Prometheus │  │    Loki     │  │    Tempo    │
│  (Metrics)  │  │   (Logs)    │  │  (Traces)   │
└─────────────┘  └─────────────┘  └─────────────┘
         │              │               │
         └──────────────┼───────────────┘
                        │
              ┌─────────────────────┐
              │  OpenTelemetry      │
              │  Collector          │
              │  (Unified ingestion)│
              └─────────────────────┘
                        │
              ┌─────────────────────┐
              │    Applications     │
              │  (OTEL SDK)         │
              └─────────────────────┘
```

---

## Recommended Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Metrics | Prometheus + kube-prometheus-stack | Time-series metrics |
| Logs | Loki + Promtail | Log aggregation |
| Traces | Tempo | Distributed tracing |
| Collection | OpenTelemetry Collector | Unified data ingestion |
| Visualization | Grafana | Dashboards and exploration |
| Alerting | Alertmanager | Alert routing and silencing |

---

## Core Workflow

1. **Instrument** - Add OTEL SDK to applications
2. **Collect** - Deploy OpenTelemetry Collector
3. **Store** - Configure Prometheus, Loki, Tempo backends
4. **Visualize** - Create Grafana dashboards
5. **Alert** - Define SLOs and alerting rules
6. **Correlate** - Link metrics, logs, and traces

---

## kube-prometheus-stack Setup

The easiest way to deploy a complete metrics stack:

```yaml
# values.yaml for kube-prometheus-stack
prometheus:
  prometheusSpec:
    retention: 15d
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 2Gi

    # Enable exemplars for trace correlation
    enableFeatures:
      - exemplar-storage

    # ServiceMonitor selector
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}

grafana:
  defaultDashboardsEnabled: true
  adminPassword: ${GRAFANA_ADMIN_PASSWORD}

  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-operated:9090
          isDefault: true
        - name: Loki
          type: loki
          url: http://loki:3100
        - name: Tempo
          type: tempo
          url: http://tempo:3100

alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      receiver: 'slack'
      group_by: ['alertname', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: '${SLACK_WEBHOOK_URL}'
            channel: '#alerts'
```

Install:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f values.yaml
```

---

## ServiceMonitor Pattern

Enable Prometheus scraping for any service:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
  labels:
    release: kube-prometheus  # Must match stack's selector
spec:
  namespaceSelector:
    matchNames:
      - my-app-namespace
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

---

## Loki Setup

```yaml
# loki-values.yaml
loki:
  auth_enabled: false
  storage:
    type: filesystem
  compactor:
    retention_enabled: true
    retention_delete_delay: 2h
  limits_config:
    retention_period: 30d

promtail:
  config:
    clients:
      - url: http://loki:3100/loki/api/v1/push
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: app
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
```

---

## Tempo Setup

```yaml
# tempo-values.yaml
tempo:
  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces

  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

  # Enable search
  search_enabled: true

  # Metrics generator for trace-derived metrics
  metricsGenerator:
    enabled: true
    remoteWriteUrl: http://prometheus:9090/api/v1/write
```

---

## OpenTelemetry Collector

Central collection point for all telemetry:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024

      memory_limiter:
        check_interval: 1s
        limit_mib: 512

    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"

      loki:
        endpoint: http://loki:3100/loki/api/v1/push

      otlp:
        endpoint: tempo:4317
        tls:
          insecure: true

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]

        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [prometheus]

        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [loki]
```

---

## Application Instrumentation

### Go (with OTEL SDK)

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() (*trace.TracerProvider, error) {
    exporter, err := otlptracegrpc.New(context.Background(),
        otlptracegrpc.WithEndpoint("otel-collector:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("my-service"),
        )),
    )
    otel.SetTracerProvider(tp)
    return tp, nil
}
```

### Environment Variables

Configure via environment (no code changes):

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector:4317"
  - name: OTEL_SERVICE_NAME
    value: "my-service"
  - name: OTEL_TRACES_SAMPLER
    value: "parentbased_traceidratio"
  - name: OTEL_TRACES_SAMPLER_ARG
    value: "0.1"  # 10% sampling
```

---

## SLO/SLI Design

### The RED Method (for services)

- **R**ate - Request throughput
- **E**rrors - Error rate
- **D**uration - Latency

```yaml
# PrometheusRule for RED method SLOs
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-slos
spec:
  groups:
    - name: my-app.slos
      rules:
        # Error rate SLI (target: 99.9% success)
        - record: my_app:error_rate:5m
          expr: |
            sum(rate(http_requests_total{job="my-app",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="my-app"}[5m]))

        # Latency SLI (target: p99 < 500ms)
        - record: my_app:latency_p99:5m
          expr: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{job="my-app"}[5m])) by (le)
            )

        # Burn rate alert (1h budget burn)
        - alert: HighErrorBurnRate
          expr: my_app:error_rate:5m > 0.001 * 14.4
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error burn rate for my-app"
```

---

## Key PromQL Queries

### Request Rate
```promql
sum(rate(http_requests_total{job="my-app"}[5m])) by (method, status)
```

### Error Rate
```promql
sum(rate(http_requests_total{job="my-app",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{job="my-app"}[5m]))
```

### Latency (p50, p95, p99)
```promql
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{job="my-app"}[5m])) by (le)
)
```

### Pod Memory Usage
```promql
container_memory_working_set_bytes{namespace="my-ns", pod=~"my-app.*"}
/ container_spec_memory_limit_bytes{namespace="my-ns", pod=~"my-app.*"}
```

### CPU Throttling
```promql
rate(container_cpu_cfs_throttled_seconds_total{namespace="my-ns"}[5m])
```

---

## Key LogQL Queries

### Error logs
```logql
{namespace="my-ns", app="my-app"} |= "error" | json | level="error"
```

### Logs with trace correlation
```logql
{namespace="my-ns"} | json | trace_id="abc123"
```

### Rate of errors
```logql
sum(rate({namespace="my-ns"} |= "error" [5m]))
```

---

## Best Practices

### DO:
- Use structured JSON logging
- Include trace_id and span_id in logs
- Set appropriate retention periods
- Use recording rules for expensive queries
- Configure resource limits for all components
- Use exemplars to link metrics to traces
- Implement sampling for high-volume traces

### DON'T:
- Log sensitive data (PII, secrets)
- Store metrics indefinitely (cost!)
- Create high-cardinality labels
- Alert on symptoms, not causes
- Ignore the correlation between pillars
- Over-instrument (sample instead)

---

## Related References

- [references/prometheus-stack.md](references/prometheus-stack.md) - Prometheus patterns
- [references/loki-logging.md](references/loki-logging.md) - Logging patterns
- [references/tempo-tracing.md](references/tempo-tracing.md) - Tracing patterns
- [references/grafana-dashboards.md](references/grafana-dashboards.md) - Dashboard examples
