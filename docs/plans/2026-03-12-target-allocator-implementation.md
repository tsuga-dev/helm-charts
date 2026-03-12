# Target Allocator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `targetAllocator.enabled` flag that deploys a standalone `TargetAllocator` CR and a paired `OpenTelemetryCollector` CR in `statefulset` mode.

**Architecture:** Two new Kubernetes resources gated on `targetAllocator.enabled: true` — a `TargetAllocator` CR (`opentelemetry.io/v1alpha1`) that distributes Prometheus targets, and a `OpenTelemetryCollector` CR in `statefulset` mode linked to it via the `opentelemetry.io/target-allocator` label. The StatefulSet collector follows the same config merge pattern as the existing `agent` (daemonset) and `cluster` (deployment) collectors.

**Tech Stack:** Helm 3, Helm unittest plugin (`helm unittest .` from `charts/opentelemetry-kube-stack/`), Go templates, `opentelemetry.io/v1beta1` OpenTelemetryCollector CRD, `opentelemetry.io/v1alpha1` TargetAllocator CRD.

**Key files to understand before starting:**
- `templates/daemonset.yaml` — pattern to follow for the new statefulset template
- `templates/cluster-receiver.yaml` — pattern for collector CR structure
- `templates/_default-deamonset-config.tpl` — pattern for default config template
- `templates/_otel_config.yaml` — the merge helper reused by all collectors
- `templates/rbac.yaml` — where to add the PrometheusCR RBAC rules
- `values.yaml` — where to add `targetAllocator` and `statefulset` blocks
- `values.schema.json` — where to add JSON schema for new values
- `tests/daemonset_test.yaml` — pattern for writing unittest assertions

---

### Task 1: Default StatefulSet OTel config template

**Files:**
- Create: `charts/opentelemetry-kube-stack/templates/_default-statefulset-config.tpl`

**Step 1: Write the failing test**

Create `charts/opentelemetry-kube-stack/tests/statefulset_test.yaml`:

```yaml
suite: statefulset tests
templates:
  - statefulset.yaml
tests:
  - it: should not render when targetAllocator disabled
    set:
      targetAllocator.enabled: false
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - hasDocuments:
          count: 0
```

**Step 2: Run test to verify it fails**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "statefulset tests"
```

Expected: FAIL — `statefulset.yaml` does not exist yet.

**Step 3: Create the default config template**

Create `charts/opentelemetry-kube-stack/templates/_default-statefulset-config.tpl`:

```
{{- define "tsuga-otel.statefulset.config.default" -}}
receivers:
  prometheus:
    config:
      scrape_configs: []
processors:
  batch:
    send_batch_size: 5000
    send_batch_max_size: 5000
  k8sattributes:
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.deployment.name
        - k8s.statefulset.name
        - k8s.daemonset.name
        - k8s.cronjob.name
        - k8s.job.name
        - k8s.node.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.pod.start_time
      labels:
        - tag_name: service.name
          key: resource.opentelemetry.io/service.name
          from: pod
        - tag_name: service.version
          key: resource.opentelemetry.io/service.version
          from: pod
        - tag_name: env
          key: resource.opentelemetry.io/env
          from: pod
        - tag_name: team
          key: resource.opentelemetry.io/team
          from: pod
      annotations:
        - tag_name: service.name
          key: resource.opentelemetry.io/service.name
          from: pod
        - tag_name: service.version
          key: resource.opentelemetry.io/service.version
          from: pod
        - tag_name: env
          key: resource.opentelemetry.io/env
          from: pod
        - tag_name: team
          key: resource.opentelemetry.io/team
          from: pod
    passthrough: false
    pod_association:
      - sources:
        - from: resource_attribute
          name: k8s.pod.ip
      - sources:
        - from: resource_attribute
          name: k8s.pod.uid
      - sources:
        - from: connection
  {{- if .Values.clusterName }}
  resource:
    attributes:
      - key: k8s.cluster.name
        value: {{ .Values.clusterName }}
        action: upsert
  {{- end }}
exporters:
  {{include "opentelemetry-kube-stack.tsugaExporters" . | nindent 2}}
service:
  pipelines:
    metrics:
      receivers:
        - prometheus
      processors:
        - k8sattributes
        - batch
        {{- if .Values.clusterName }}
        - resource
        {{- end }}
      exporters:
        - otlphttp/tsuga
{{- end}}
```

**Step 4: Create the minimal statefulset.yaml to make the test pass**

Create `charts/opentelemetry-kube-stack/templates/statefulset.yaml`:

```
{{- if .Values.targetAllocator.enabled }}
{{- $default := include "tsuga-otel.statefulset.config.default" . | fromYaml }}
{{- $ctx := merge (dict "defaultConfig" $default "customConfig" .Values.statefulset.customConfig) .Values.statefulset.config }}
{{- include "opentelemetry-kube-stack.validateResourceNames" . }}
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: {{ include "opentelemetry-kube-stack.fullname" . }}-statefulset
  labels:
    {{- include "opentelemetry-kube-stack.componentLabels" (dict "component" "statefulset" "Values" .Values "Release" .Release "Chart" .Chart) | nindent 4 }}
    opentelemetry.io/target-allocator: {{ include "opentelemetry-kube-stack.fullname" . }}-ta
  annotations:
    meta.helm.sh/release-name: {{ .Release.Name | quote }}
    meta.helm.sh/release-namespace: {{ .Release.Namespace | quote }}
spec:
  mode: statefulset
  replicas: {{ .Values.statefulset.replicas | default 1 }}
  image: {{ .Values.statefulset.image | default "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s" }}
  {{- if or .Values.statefulset.resources .Values.resources }}
  resources:
    {{- if .Values.statefulset.resources }}
    {{- toYaml .Values.statefulset.resources | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.resources | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if or .Values.statefulset.nodeSelector .Values.nodeSelector }}
  nodeSelector:
    {{- if .Values.statefulset.nodeSelector }}
    {{- toYaml .Values.statefulset.nodeSelector | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.nodeSelector | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if or .Values.statefulset.tolerations .Values.tolerations }}
  tolerations:
    {{- if .Values.statefulset.tolerations }}
    {{- toYaml .Values.statefulset.tolerations | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.tolerations | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if or .Values.statefulset.affinity .Values.affinity }}
  affinity:
    {{- if .Values.statefulset.affinity }}
    {{- toYaml .Values.statefulset.affinity | nindent 4 }}
    {{- else }}
    {{- toYaml .Values.affinity | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if .Values.serviceAccount.create }}
  serviceAccount: {{ .Values.serviceAccount.name | default (include "opentelemetry-kube-stack.serviceAccountName" .) }}
  {{- end }}
  env:
    {{- include "opentelemetry-kube-stack.collectorEnv" . | nindent 4 }}
    {{- if .Values.statefulset.extraEnvs }}
    {{- toYaml .Values.statefulset.extraEnvs | nindent 4 }}
    {{- end }}
  config:
    {{- include "opentelemetry-kube-stack.otelConfig" $ctx | trim | nindent 4 }}
{{- end }}
```

**Step 5: Run test to verify it passes**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "statefulset tests"
```

Expected: PASS

**Step 6: Commit**

```bash
git add charts/opentelemetry-kube-stack/templates/_default-statefulset-config.tpl \
        charts/opentelemetry-kube-stack/templates/statefulset.yaml \
        charts/opentelemetry-kube-stack/tests/statefulset_test.yaml
git commit -m "feat(otel-kube-stack): add statefulset collector template"
```

---

### Task 2: TargetAllocator CR template

**Files:**
- Create: `charts/opentelemetry-kube-stack/templates/target-allocator.yaml`
- Create: `charts/opentelemetry-kube-stack/tests/target-allocator_test.yaml`

**Step 1: Write the failing test**

Create `charts/opentelemetry-kube-stack/tests/target-allocator_test.yaml`:

```yaml
suite: target-allocator tests
templates:
  - target-allocator.yaml
tests:
  - it: should not render when targetAllocator disabled
    set:
      targetAllocator.enabled: false
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - hasDocuments:
          count: 0

  - it: should create TargetAllocator CR when enabled
    set:
      targetAllocator.enabled: true
      serviceAccount.create: true
      serviceAccount.name: ""
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - isKind:
          of: TargetAllocator
      - equal:
          path: spec.serviceAccount
          value: "test-release-opentelemetry-kube-stack"
      - equal:
          path: spec.allocationStrategy
          value: "consistent-hashing"

  - it: should set prometheusCR fields when enabled
    set:
      targetAllocator.enabled: true
      targetAllocator.spec.prometheusCR.enabled: true
      targetAllocator.spec.prometheusCR.serviceMonitorSelector.matchLabels.release: "test"
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - equal:
          path: spec.prometheusCR.enabled
          value: true
      - equal:
          path: spec.prometheusCR.serviceMonitorSelector.matchLabels.release
          value: "test"
```

**Step 2: Run test to verify it fails**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "target-allocator tests"
```

Expected: FAIL — `target-allocator.yaml` does not exist yet.

**Step 3: Create the target-allocator.yaml template**

Create `charts/opentelemetry-kube-stack/templates/target-allocator.yaml`:

```
{{- if .Values.targetAllocator.enabled }}
{{- include "opentelemetry-kube-stack.validateResourceNames" . }}
apiVersion: opentelemetry.io/v1alpha1
kind: TargetAllocator
metadata:
  name: {{ include "opentelemetry-kube-stack.fullname" . }}-ta
  labels:
    {{- include "opentelemetry-kube-stack.componentLabels" (dict "component" "target-allocator" "Values" .Values "Release" .Release "Chart" .Chart) | nindent 4 }}
  annotations:
    meta.helm.sh/release-name: {{ .Release.Name | quote }}
    meta.helm.sh/release-namespace: {{ .Release.Namespace | quote }}
spec:
  serviceAccount: {{ .Values.serviceAccount.name | default (include "opentelemetry-kube-stack.serviceAccountName" .) }}
  {{- with .Values.targetAllocator.spec }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
```

**Step 4: Run test to verify it passes**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "target-allocator tests"
```

Expected: PASS

**Step 5: Commit**

```bash
git add charts/opentelemetry-kube-stack/templates/target-allocator.yaml \
        charts/opentelemetry-kube-stack/tests/target-allocator_test.yaml
git commit -m "feat(otel-kube-stack): add TargetAllocator CR template"
```

---

### Task 3: Add statefulset tests for the collector-TA link

**Files:**
- Modify: `charts/opentelemetry-kube-stack/tests/statefulset_test.yaml`

**Step 1: Add tests for enabled state and TA label**

Append to `charts/opentelemetry-kube-stack/tests/statefulset_test.yaml`:

```yaml
  - it: should create statefulset collector when targetAllocator enabled
    set:
      targetAllocator.enabled: true
      serviceAccount.create: true
      serviceAccount.name: ""
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - isKind:
          of: OpenTelemetryCollector
      - equal:
          path: spec.mode
          value: statefulset
      - equal:
          path: spec.serviceAccount
          value: "test-release-opentelemetry-kube-stack"
      - equal:
          path: metadata.labels["opentelemetry.io/target-allocator"]
          value: "test-release-opentelemetry-kube-stack-ta"

  - it: should use custom replicas
    set:
      targetAllocator.enabled: true
      statefulset.replicas: 3
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - equal:
          path: spec.replicas
          value: 3
```

**Step 2: Run tests**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "statefulset tests"
```

Expected: PASS

**Step 3: Commit**

```bash
git add charts/opentelemetry-kube-stack/tests/statefulset_test.yaml
git commit -m "test(otel-kube-stack): add statefulset collector-TA link tests"
```

---

### Task 4: Add values.yaml blocks

**Files:**
- Modify: `charts/opentelemetry-kube-stack/values.yaml`

**Step 1: Add the new values blocks**

Add after the `autoInstrumentation` block and before the `tsuga` block in `values.yaml`:

```yaml
# =============================================================================
# TARGET ALLOCATOR CONFIGURATION
# =============================================================================
# The Target Allocator decouples Prometheus service discovery from metric
# collection. When enabled, it deploys a TargetAllocator CR and a paired
# StatefulSet OpenTelemetryCollector CR.
# Requires the OpenTelemetry Operator to be installed.
targetAllocator:
  # -- Enable Target Allocator and paired StatefulSet collector
  # @default -- false
  enabled: false
  # -- TargetAllocator CR spec (full passthrough)
  # All fields are passed directly to the TargetAllocator CR spec.
  # Ref: https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#targetallocator
  spec:
    # -- Allocation strategy for distributing targets across collector replicas
    # Options: consistent-hashing (default), least-weighted, per-node
    # @default -- "consistent-hashing"
    allocationStrategy: consistent-hashing
    # -- PrometheusCR configuration
    # When enabled, the Target Allocator discovers ServiceMonitor and PodMonitor CRs.
    # Requires monitoring.coreos.com RBAC rules (added automatically when enabled).
    prometheusCR:
      # -- Enable ServiceMonitor/PodMonitor discovery
      # @default -- false
      enabled: false
      # -- Selector for ServiceMonitor resources
      # An empty selector ({}) matches all ServiceMonitors in all namespaces.
      # @default -- {}
      serviceMonitorSelector: {}
      # -- Selector for PodMonitor resources
      # An empty selector ({}) matches all PodMonitors in all namespaces.
      # @default -- {}
      podMonitorSelector: {}

# =============================================================================
# STATEFULSET COLLECTOR CONFIGURATION
# =============================================================================
# Configuration for the StatefulSet OpenTelemetryCollector paired with the
# Target Allocator. Only used when targetAllocator.enabled: true.
statefulset:
  # -- Number of StatefulSet collector replicas
  # The Target Allocator distributes targets evenly across replicas.
  # @default -- 1
  replicas: 1
  # -- OpenTelemetry Collector image for StatefulSet collector
  # Defaults to: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s
  # @default -- ""
  image: ""
  # -- Extra environment variables for StatefulSet collector
  # @default -- []
  extraEnvs: []

  # -- Replace default config with complete custom configuration
  # When set, completely replaces the default collector configuration.
  # @default -- {}
  customConfig: {}

  # -- StatefulSet collector configuration (merge-based approach)
  # Default config includes: prometheus receiver, k8sattributes processor, batch processor, tsuga exporter.
  config:
    # -- Additional receivers to merge into the collector configuration
    # @default -- {}
    extraReceivers: {}
    # -- Additional processors to merge into the collector configuration
    # @default -- {}
    extraProcessors: {}
    # -- Additional exporters to merge into the collector configuration
    # @default -- {}
    extraExporters: {}
    # -- Additional connectors to merge into the collector configuration
    # @default -- {}
    extraConnectors: {}
    # -- Service configuration
    service:
      # -- Additional extensions to add to the service configuration
      # @default -- []
      extraExtensions: []
      # -- Pipeline configuration
      pipelines:
        # -- Metrics pipeline configuration
        metrics:
          # -- Additional exporters to add to the metrics pipeline
          # @default -- []
          extraExporters: []
          # -- Additional processors to add to the metrics pipeline
          # @default -- []
          extraProcessors: []
          # -- Additional receivers to add to the metrics pipeline
          # @default -- []
          extraReceivers: []
        # -- Additional pipelines
        # @default -- {}
        extraPipelines: {}

  # -- StatefulSet-specific resource limits and requests
  # If not set, inherits from global resources configuration
  # @default -- {}
  resources: {}
  # -- StatefulSet-specific node selector
  # @default -- {}
  nodeSelector: {}
  # -- StatefulSet-specific tolerations
  # @default -- {}
  tolerations: {}
  # -- StatefulSet-specific affinity rules
  # @default -- {}
  affinity: {}
```

**Step 2: Run the full unittest suite to verify nothing breaks**

```bash
cd charts/opentelemetry-kube-stack
helm unittest .
```

Expected: All existing tests PASS, new tests PASS.

**Step 3: Commit**

```bash
git add charts/opentelemetry-kube-stack/values.yaml
git commit -m "feat(otel-kube-stack): add targetAllocator and statefulset values"
```

---

### Task 5: RBAC — PrometheusCR rules

**Files:**
- Modify: `charts/opentelemetry-kube-stack/templates/rbac.yaml`
- Modify: `charts/opentelemetry-kube-stack/tests/rbac_test.yaml`

**Step 1: Read the existing rbac_test.yaml to understand current tests**

```bash
cat charts/opentelemetry-kube-stack/tests/rbac_test.yaml
```

**Step 2: Add a failing test**

Append to `charts/opentelemetry-kube-stack/tests/rbac_test.yaml`:

```yaml
  - it: should not include monitoring.coreos.com rules by default
    set:
      rbac.create: true
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - notContains:
          path: rules
          content:
            apiGroups: ["monitoring.coreos.com"]

  - it: should include monitoring.coreos.com rules when prometheusCR enabled
    set:
      rbac.create: true
      targetAllocator.enabled: true
      targetAllocator.spec.prometheusCR.enabled: true
      tsuga.otlpEndpoint: "https://test-endpoint.com"
      tsuga.apiKey: "test-api-key"
    release:
      name: "test-release"
    asserts:
      - contains:
          path: rules
          content:
            apiGroups: ["monitoring.coreos.com"]
            resources: ["servicemonitors", "podmonitors"]
            verbs: ["get", "list", "watch"]
```

**Step 3: Run test to verify it fails**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "rbac"
```

Expected: FAIL on the prometheusCR test.

**Step 4: Add the conditional rules to rbac.yaml**

In `charts/opentelemetry-kube-stack/templates/rbac.yaml`, add before the closing `{{- end }}`:

```yaml
{{- if and .Values.targetAllocator.enabled .Values.targetAllocator.spec.prometheusCR.enabled }}
# PrometheusCR discovery for Target Allocator
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors", "podmonitors"]
  verbs: ["get", "list", "watch"]
{{- end }}
```

**Step 5: Run tests**

```bash
cd charts/opentelemetry-kube-stack
helm unittest . --filter "rbac"
```

Expected: PASS

**Step 6: Commit**

```bash
git add charts/opentelemetry-kube-stack/templates/rbac.yaml \
        charts/opentelemetry-kube-stack/tests/rbac_test.yaml
git commit -m "feat(otel-kube-stack): add PrometheusCR RBAC rules for Target Allocator"
```

---

### Task 6: Update values.schema.json

**Files:**
- Modify: `charts/opentelemetry-kube-stack/values.schema.json`

**Step 1: Add `targetAllocator` and `statefulset` schema entries**

In `values.schema.json`, inside the top-level `"properties"` object, add:

```json
"targetAllocator": {
    "type": "object",
    "properties": {
        "enabled": {
            "type": "boolean"
        },
        "spec": {
            "type": "object",
            "properties": {
                "allocationStrategy": {
                    "type": "string"
                },
                "prometheusCR": {
                    "type": "object",
                    "properties": {
                        "enabled": {
                            "type": "boolean"
                        },
                        "serviceMonitorSelector": {
                            "type": "object"
                        },
                        "podMonitorSelector": {
                            "type": "object"
                        }
                    }
                }
            }
        }
    }
},
"statefulset": {
    "type": "object",
    "properties": {
        "replicas": {
            "type": "integer"
        },
        "image": {
            "type": "string"
        },
        "extraEnvs": {
            "type": "array"
        },
        "customConfig": {
            "type": "object"
        },
        "config": {
            "type": "object",
            "properties": {
                "extraReceivers": { "type": "object" },
                "extraProcessors": { "type": "object" },
                "extraExporters": { "type": "object" },
                "extraConnectors": { "type": "object" },
                "service": {
                    "type": "object",
                    "properties": {
                        "extraExtensions": { "type": "array" },
                        "pipelines": {
                            "type": "object",
                            "properties": {
                                "extraPipelines": { "type": "object" },
                                "metrics": {
                                    "type": "object",
                                    "properties": {
                                        "extraExporters": { "type": "array" },
                                        "extraProcessors": { "type": "array" },
                                        "extraReceivers": { "type": "array" }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        "resources": { "type": "object" },
        "nodeSelector": { "type": "object" },
        "tolerations": { "type": "object" },
        "affinity": { "type": "object" }
    }
}
```

**Step 2: Validate schema is valid JSON**

```bash
cd charts/opentelemetry-kube-stack
python3 -c "import json; json.load(open('values.schema.json')); print('valid')"
```

Expected: `valid`

**Step 3: Run full helm lint**

```bash
cd charts/opentelemetry-kube-stack
helm lint . --set tsuga.otlpEndpoint="https://test-endpoint.com" --set tsuga.apiKey="test-api-key"
```

Expected: `0 chart(s) failed`

**Step 4: Commit**

```bash
git add charts/opentelemetry-kube-stack/values.schema.json
git commit -m "feat(otel-kube-stack): add schema validation for targetAllocator and statefulset values"
```

---

### Task 7: Add example and render outputs

**Files:**
- Create: `charts/opentelemetry-kube-stack/examples/target-allocator/values.yaml`
- Create: `charts/opentelemetry-kube-stack/examples/target-allocator/rendered/` (generated)

**Step 1: Create the example values file**

Create `charts/opentelemetry-kube-stack/examples/target-allocator/values.yaml`:

```yaml
targetAllocator:
  enabled: true
  spec:
    allocationStrategy: consistent-hashing
    prometheusCR:
      enabled: false

statefulset:
  replicas: 2

tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com"
  apiKey: "your-api-key"
```

**Step 2: Render the example**

```bash
cd charts/opentelemetry-kube-stack
mkdir -p examples/target-allocator/rendered
helm template test-release . \
  -f examples/target-allocator/values.yaml \
  --set tsuga.otlpEndpoint="https://example.com" \
  --set tsuga.apiKey="example-key" \
  | grep -v "^#" \
  | csplit - '/^---$/' '{*}' --prefix=examples/target-allocator/rendered/doc --suffix-format='%02d.yaml' -z 2>/dev/null || true
```

> Note: The Makefile uses a custom render script. Check `examples/default/` for the naming pattern — rename rendered files to match (e.g., `statefulset.yaml`, `target-allocator.yaml`, `serviceaccount.yaml`, `rbac.yaml`).

Alternatively, render directly to named files:

```bash
helm template test-release . \
  -f examples/target-allocator/values.yaml \
  --set tsuga.otlpEndpoint="https://example.com" \
  --set tsuga.apiKey="example-key" \
  --show-only templates/statefulset.yaml > examples/target-allocator/rendered/statefulset.yaml

helm template test-release . \
  -f examples/target-allocator/values.yaml \
  --set tsuga.otlpEndpoint="https://example.com" \
  --set tsuga.apiKey="example-key" \
  --show-only templates/target-allocator.yaml > examples/target-allocator/rendered/target-allocator.yaml
```

**Step 3: Run the full test suite one final time**

```bash
cd charts/opentelemetry-kube-stack
helm unittest .
helm lint . --set tsuga.otlpEndpoint="https://test-endpoint.com" --set tsuga.apiKey="test-api-key"
```

Expected: All tests PASS, lint clean.

**Step 4: Commit**

```bash
git add charts/opentelemetry-kube-stack/examples/target-allocator/
git commit -m "feat(otel-kube-stack): add target-allocator example"
```
