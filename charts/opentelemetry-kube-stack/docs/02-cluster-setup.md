# Cluster Setup Guide

This guide walks you through the complete process of installing and configuring OpenTelemetry in your Kubernetes cluster. Follow these steps to set up comprehensive observability.

## Learning Objectives

- Install the OpenTelemetry Operator
- Deploy the OpenTelemetry Kubernetes Stack using Helm
- Configure authentication with Tsuga
- Verify the deployment
- Understand basic configuration options

## Step 1: Install OpenTelemetry Operator

The OpenTelemetry Operator is required to manage OpenTelemetry Collector instances in your cluster.

### Install the Operator

```bash
# Install the latest OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

### Verify Operator Installation

```bash
# Check operator deployment
kubectl get pods -n opentelemetry-operator-system

# Expected output: pods should be in Running state
# NAME                                          READY   STATUS    RESTARTS   AGE
# opentelemetry-operator-controller-manager-*   2/2     Running   0          30s
```

Wait for the operator to be ready:

```bash
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n opentelemetry-operator-system \
  --timeout=90s
```

## Step 2: Prepare Installation

### Create a Namespace (Optional but Recommended)

```bash
# Create dedicated namespace for observability
kubectl create namespace observability

# Set as default context
kubectl config set-context --current --namespace=observability
```

### Gather Your Tsuga Credentials

Before installation, you'll need:

1. **Tsuga OTLP Endpoint**: Your Tsuga instance endpoint
   - Format: `https://your-tsuga-instance.com/v1/otlp` or similar
   - Contact your Tsuga administrator if unsure

2. **Tsuga API Key**: Authentication bearer token
   - Keep this secure - never commit to version control
   - Store in a password manager or secret management system

## Step 3: Install the Helm Chart

You have four installation options. Choose the one that best fits your workflow.

### Option 1: Guided Setup (Recommended for First-Time Users)

The chart includes an interactive deployment script (`deploy.sh`) that guides you through the complete setup process, including prerequisites installation and configuration.

#### Prerequisites

- `kubectl` installed and configured with cluster access
- `helm` installed
- Access to the chart directory

#### Usage

1. **Navigate to the chart directory**:
   ```bash
   cd charts/opentelemetry-kube-stack
   ```

2. **Make the script executable** (if not already):
   ```bash
   chmod +x deploy.sh
   ```

3. **Run the script**:
   ```bash
   ./deploy.sh
   ```

#### What the Script Does

The `deploy.sh` script is an interactive tool that:

- ✅ **Checks prerequisites**: Verifies `kubectl` and `helm` are installed
- ✅ **Collects configuration**: Prompts for:
  - Namespace for the deployment (default: `otel`)
  - Tsuga OTLP endpoint URL
  - Tsuga API key (input is hidden for security)
  - Cluster name (for resource attributes)
  - Optional collection settings (network metrics, process metrics)
- ✅ **Validates Kubernetes context**: Shows current context and asks for confirmation
- ✅ **Installs dependencies**:
  - cert-manager (if not already installed)
  - OpenTelemetry Operator (if not already installed)
- ✅ **Waits for readiness**: Ensures all components are ready before proceeding
- ✅ **Deploys the chart**: Installs with your configuration
- ✅ **Verifies deployment**: Checks that pods are running correctly

#### Interactive Prompts

The script will ask you for:

1. **Namespace**: Where to deploy (default: `otel`)
2. **Tsuga Endpoint**: Your OTLP endpoint URL
3. **Tsuga API Key**: Your authentication key (input is hidden)
4. **Cluster Name**: Identifier for multi-cluster setups
5. **Network Metrics**: Whether to collect network interface statistics
6. **Process Metrics**: Whether to collect process-level metrics

#### Example Session

```bash
$ ./deploy.sh

========================================
  OpenTelemetry Kubernetes Stack Deploy
========================================

[Step 0] Namespace Configuration
----------------------------------------
Please specify the namespace for the OpenTelemetry deployment.
Enter namespace (default: otel): observability
✅ Using namespace: observability

[Step 0.5] Tsuga Configuration
----------------------------------------
Please provide your OpenTelemetry endpoint URL:
Enter OTLP endpoint URL: https://your-tsuga-endpoint.com/v1/otlp
✅ Tsuga endpoint configured

Enter API key: [hidden input]
✅ Tsuga API key configured

[Step 0.6] Collection Settings Configuration
----------------------------------------
Collect network metrics? (y/N): n
⚠️  Network metrics collection disabled

Collect process metrics? (y/N): n
⚠️  Process metrics collection disabled

[Step 1] Checking Kubernetes Context
----------------------------------------
Current Kubernetes Context: my-cluster
Continue with deployment? (y/N): y
✅ Context confirmed

[Step 2] Checking cert-manager Installation
----------------------------------------
✅ cert-manager is running

[Step 3] Checking OpenTelemetry Operator Installation
----------------------------------------
✅ OpenTelemetry operator is running

[Step 4] Deploying OpenTelemetry Helm Chart
----------------------------------------
✅ Helm chart deployed successfully

[Step 5] Verifying Deployment
----------------------------------------
✅ Deployment verification completed
```

#### Optional: Using a Values File

If you have a `values.yaml` file in the chart directory, the script will detect it and offer to use the existing configuration. You can also manually create or update `values.yaml` before running the script:

```bash
# Create or edit values.yaml
vim values.yaml

# Run the script
./deploy.sh
```

The script will detect existing values and prompt whether to use them or reconfigure.

#### Upgrading an Existing Installation

If you run the script and a release already exists, it will prompt you to upgrade:

```bash
⚠️  Release 'otel-stack' already exists in namespace 'observability'
Upgrade existing release? (Y/n): y
```

#### Advantages

- **Interactive**: Guides you through each step
- **Safe**: Validates inputs and shows what will happen
- **Complete**: Handles prerequisites automatically
- **User-friendly**: Clear prompts and colored output
- **Flexible**: Can use existing values.yaml or configure interactively

**Use Case**: Best for first-time deployments, users who prefer guided setup, or when you want to ensure all prerequisites are properly installed.

### Option 2: Using Chart Repository

This is the recommended approach for production deployments:

```bash
# Add the Helm repository
helm repo add tsuga-charts https://tsuga-dev.github.io/helm-charts/
helm repo update

# Install with inline values
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --create-namespace \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com/v1/otlp" \
  --set tsuga.apiKey="your-api-key-here"
```

### Option 3: Using Values File

For repeatable deployments and version control:

```bash
# Create values file
cat > otel-values.yaml << EOF
tsuga:
  otlpEndpoint: "https://your-tsuga-endpoint.com/v1/otlp"
  apiKey: "your-api-key-here"

secret:
  create: true

clusterName: "production-cluster"
EOF

# Install using values file
helm install my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --create-namespace \
  -f otel-values.yaml
```

**Security Note**: Never commit values files containing API keys to version control. Use `--set` flags or external secret management.

### Option 4: Local Chart Directory

For development or custom modifications:

```bash
# Navigate to chart directory
cd charts/opentelemetry-kube-stack

# Install from local directory
helm install my-otel-stack . \
  --namespace observability \
  --create-namespace \
  --set secret.create=true \
  --set tsuga.otlpEndpoint="https://your-tsuga-endpoint.com/v1/otlp" \
  --set tsuga.apiKey="your-api-key-here"
```


## Step 4: Verify Installation

After installation, verify that all components are running correctly.

### Check Pods Status

```bash
# Check all OpenTelemetry pods
kubectl get pods -n observability -l app.kubernetes.io/name=opentelemetry-kube-stack

# Expected output:
# NAME                                           READY   STATUS    RESTARTS   AGE
# my-otel-stack-agent-xxxxx                      1/1     Running   0          30s
# my-otel-stack-agent-xxxxx                      1/1     Running   0          30s
# my-otel-stack-cluster-receiver-xxxxx-xxxxx     1/1     Running   0          30s
```

You should see:
- One agent pod per node (DaemonSet)
- One or more cluster receiver pods (Deployment, depends on replicas)

### Check DaemonSet

```bash
# Verify agent DaemonSet
kubectl get daemonset -n observability

# Expected: NumberReady should match number of nodes
# NAME                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
# my-otel-stack-agent       3         3         3       3            3
```

### Check Deployment

```bash
# Verify cluster receiver deployment
kubectl get deployment -n observability

# Expected: All replicas should be ready
# NAME                            READY   UP-TO-DATE   AVAILABLE
# my-otel-stack-cluster-receiver  1/1     1            1
```

### Check Secret

```bash
# Verify secret was created
kubectl get secret -n observability | grep otel

# Inspect secret (credentials will be base64 encoded)
kubectl get secret my-otel-stack-otel-secret -n observability -o yaml
```

### Check OpenTelemetryCollector Resources

```bash
# Check OpenTelemetryCollector custom resources
kubectl get opentelemetrycollector -n observability

# Expected:
# NAME                            MODE         VERSION   AGE
# my-otel-stack-agent             daemonset    0.xxx     2m
# my-otel-stack-cluster-receiver  deployment   0.xxx     2m
```

## Step 5: Basic Configuration

### Set Cluster Name

Add a cluster identifier for multi-cluster environments:

```bash
helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --set clusterName="production-cluster" \
  --reuse-values
```

### Disable Log Collection

If you don't want to collect container logs:

```bash
helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --set agent.collectLogs=false \
  --reuse-values
```

### Adjust Resource Limits

For production workloads:

```bash
helm upgrade my-otel-stack tsuga-charts/opentelemetry-kube-stack \
  --namespace observability \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=1Gi \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=256Mi \
  --reuse-values
```

## Post-Installation Checklist

- [ ] OpenTelemetry Operator is running
- [ ] Agent DaemonSet has pods on all nodes
- [ ] Cluster Receiver deployment is ready
- [ ] Secret created with correct credentials
- [ ] No errors in collector logs
- [ ] Environment variables configured correctly
- [ ] Cluster name set (if using multi-cluster)

## Understanding the Deployment

### What Gets Deployed

1. **OpenTelemetryCollector Resources**: Custom resources managed by the operator
2. **Agent DaemonSet**: Collector pods on each node
3. **Cluster Receiver Deployment**: Centralized collector
4. **ServiceAccount**: For RBAC permissions
5. **RBAC Resources**: ClusterRole and ClusterRoleBinding
6. **Secret**: Contains Tsuga credentials

### Default Configuration

By default, the chart configures:

- **Agent collects**:
  - Host metrics (CPU, memory, disk, filesystem, load)
  - Kubernetes metrics (via kubelet)
  - Container logs (from `/var/log/pods`)
  - Application telemetry (OTLP, Jaeger, Zipkin)

- **Cluster Receiver collects**:
  - Cluster-level metrics (via `k8s_cluster` receiver)
  - Entity events (Kubernetes object changes)

- **Both forward to**: Your Tsuga endpoint

## Next Steps

Now that your cluster is instrumented:

1. **Instrument Applications** → See [Application Instrumentation Guide](03-application-instrumentation.md)
2. **Customize Configuration** → See [Configuration Examples](04-configuration-examples.md)
3. **Troubleshoot Issues** → See [Troubleshooting Guide](05-troubleshooting.md)

## Common Installation Issues

### Operator Not Ready

**Problem**: Operator pods in `CrashLoopBackOff` or `Pending`

**Solutions**:
```bash
# Check operator logs
kubectl logs -n opentelemetry-operator-system -l control-plane=controller-manager

# Check for resource constraints
kubectl describe pod -n opentelemetry-operator-system -l control-plane=controller-manager
```

### Agent Pods Not Starting

**Problem**: Agent DaemonSet pods not ready

**Solutions**:
```bash
# Check pod status
kubectl describe pod -n observability -l app.kubernetes.io/component=agent

# Check RBAC permissions
kubectl get clusterrolebinding | grep my-otel-stack
```

### Secret Not Created

**Problem**: Secret missing or credentials incorrect

**Solutions**:
```bash
# Recreate secret manually if needed
kubectl create secret generic my-otel-stack-otel-secret \
  --from-literal=TSUGA_API_KEY="your-key" \
  --from-literal=TSUGA_OTLP_ENDPOINT="https://your-endpoint.com/v1/otlp" \
  -n observability
```

## Uninstallation

If you need to remove the installation:

```bash
# Uninstall the Helm release
helm uninstall my-otel-stack -n observability

# Optionally remove the operator (if not used elsewhere)
kubectl delete -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

---

**Your cluster is now instrumented!** Continue to [Application Instrumentation Guide](03-application-instrumentation.md) to start sending telemetry from your applications.

