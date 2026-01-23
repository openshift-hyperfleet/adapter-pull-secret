# Pull Secret Adapter Helm Chart

This Helm chart deploys the HyperFleet Pull Secret Adapter using the Adapter Framework pattern. The adapter listens to PubSub messages and dynamically creates jobs to store pull secrets in GCP Secret Manager.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Adapter Framework (Deployment)                                  │
│  - Listens to PubSub messages                                    │
│  - Creates Jobs based on AdapterConfig                           │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼ (creates dynamically)
┌──────────────────────────────────────────────────────────────────┐
│  Pull Secret Job (per cluster)                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐                │
│  │ pull-secret         │  │ status-reporter     │                │
│  │ (main container)    │  │ (sidecar)           │                │
│  └─────────────────────┘  └─────────────────────┘                │
│           │                         │                            │
│           └───── shared volume ─────┘                            │
└──────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Helm 3.x installed**
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

2. **kubectl configured for your GKE cluster**
   ```bash
   gcloud container clusters get-credentials YOUR_CLUSTER_NAME \
     --zone=YOUR_ZONE \
     --project=YOUR_PROJECT_ID
   ```

3. **GCP Pub/Sub configured**
   - Topic for adapter messages
   - Subscription for the adapter

4. **Workload Identity configured**
   - Using `principalSet://` for Workload Identity Federation
   - No ServiceAccount annotation required (modern approach)

## Installation

### Quick Start

Deploy with required Pub/Sub configuration:

```bash
helm install pull-secret-adapter ./charts/pull-secret \
  --namespace hyperfleet-system \
  --create-namespace \
  --set broker.googlepubsub.projectId=my-project \
  --set broker.googlepubsub.topic=hyperfleet-events \
  --set broker.googlepubsub.subscription=pull-secret-adapter-sub \
  --set hyperfleetApi.baseUrl=https://api.hyperfleet.example.com
```

### Custom Values

Deploy with custom configuration:

```bash
helm install pull-secret-adapter ./charts/pull-secret \
  --namespace hyperfleet-system \
  --create-namespace \
  --set broker.googlepubsub.projectId=my-project \
  --set broker.googlepubsub.topic=hyperfleet-events \
  --set broker.googlepubsub.subscription=pull-secret-adapter-sub \
  --set hyperfleetApi.baseUrl=https://api.hyperfleet.example.com \
  --set pullSecretAdapter.image.tag=v1.0.0
```

### Using a Values File

Create a custom values file (`my-values.yaml`):

```yaml
broker:
  type: "googlepubsub"
  googlepubsub:
    projectId: "my-gcp-project"
    topic: "hyperfleet-events"
    subscription: "pull-secret-adapter-sub"

hyperfleetApi:
  baseUrl: "https://api.hyperfleet.example.com"
  version: "v1"

pullSecretAdapter:
  image:
    tag: "v1.0.0"
```

Then install:

```bash
helm install pull-secret-adapter ./charts/pull-secret \
  --namespace hyperfleet-system \
  --create-namespace \
  -f my-values.yaml
```

## Umbrella Chart Integration

This chart supports integration with the `hyperfleet-chart` umbrella chart.

### Adding to hyperfleet-chart

In your umbrella chart's `Chart.yaml`:

```yaml
dependencies:
  - name: pull-secret
    version: "0.1.0"
    repository: "git+https://github.com/openshift-hyperfleet/adapter-pull-secret@charts/pull-secret?ref=main"
    condition: pull-secret.enabled
```

### Global Image Override

When deployed via umbrella chart, you can set a global image registry:

```yaml
global:
  image:
    registry: "quay.io/my-org"  # Overrides all subchart image registries

pull-secret:
  enabled: true
  broker:
    googlepubsub:
      projectId: "my-project"
      topic: "hyperfleet-events"
      subscription: "pull-secret-adapter-sub"
```

## Configuration

The following table lists the configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| **Global** | | |
| `global.image.registry` | Global image registry override | `""` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |
| `replicaCount` | Number of adapter framework replicas | `1` |
| **Adapter Framework Image** | | |
| `image.registry` | Adapter framework image registry | `registry.ci.openshift.org` |
| `image.repository` | Adapter framework image repository | `ci/hyperfleet-adapter` |
| `image.tag` | Adapter framework image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `imagePullSecrets` | Image pull secrets | `[]` |
| **ServiceAccount** | | |
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name | `""` (auto-generated) |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| **RBAC** | | |
| `rbac.create` | Create RBAC resources | `true` |
| **Logging** | | |
| `logging.level` | Log level (debug, info, warn, error) | `info` |
| `logging.format` | Log format (text, json) | `text` |
| `logging.output` | Log output (stdout, stderr) | `stderr` |
| **Broker** | | |
| `broker.type` | Broker type (googlepubsub, rabbitmq) | `googlepubsub` |
| `broker.googlepubsub.projectId` | GCP project ID for Pub/Sub | `""` |
| `broker.googlepubsub.topic` | Pub/Sub topic name | `""` |
| `broker.googlepubsub.subscription` | Pub/Sub subscription name | `""` |
| `broker.googlepubsub.deadLetterTopic` | Dead letter topic (optional) | `""` |
| `broker.subscriber.parallelism` | Message processing parallelism | `1` |
| **HyperFleet API** | | |
| `hyperfleetApi.baseUrl` | HyperFleet API base URL | `""` |
| `hyperfleetApi.version` | HyperFleet API version | `v1` |
| **Pull Secret Adapter** | | |
| `pullSecretAdapter.image.registry` | Job container image registry | `quay.io/openshift-hyperfleet` |
| `pullSecretAdapter.image.repository` | Job container image repository | `pull-secret` |
| `pullSecretAdapter.image.tag` | Job container image tag | `latest` |
| `pullSecretAdapter.statusReporterImage` | Status reporter sidecar image | `registry.ci.openshift.org/ci/status-reporter:latest` |
| `pullSecretAdapter.resultsPath` | Shared result path | `/results/adapter-result.json` |
| `pullSecretAdapter.maxWaitTimeSeconds` | Max job wait time | `300` |
| `pullSecretAdapter.logLevel` | Job container log level | `info` |
| **Scheduling** | | |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `env` | Additional environment variables | `[]` |

## How It Works

1. **PubSub Message**: HyperFleet sends a message with cluster info (`clusterId`, `projectId`, `pullSecretData`)
2. **Adapter Framework**: Receives the message and creates a Job based on the AdapterConfig
3. **Pull Secret Job**: Stores the pull secret in GCP Secret Manager
4. **Status Reporter**: Reports job status back to HyperFleet API

## Usage

### Monitoring

Check deployment status:
```bash
helm status pull-secret-adapter -n hyperfleet-system
kubectl get deployment -n hyperfleet-system
kubectl get pods -n hyperfleet-system
```

View adapter logs:
```bash
kubectl logs -f deployment/pull-secret-adapter -n hyperfleet-system
```

View job logs (for a specific cluster):
```bash
kubectl logs -f job/pull-secret-<cluster-id>-<generation> -n <cluster-id>
```

### Upgrading

Upgrade the deployment:
```bash
helm upgrade pull-secret-adapter ./charts/pull-secret \
  --namespace hyperfleet-system \
  --set pullSecretAdapter.image.tag=v1.1.0
```

### Uninstalling

Remove the adapter:
```bash
helm uninstall pull-secret-adapter -n hyperfleet-system
```

## Dry Run Mode

Test without deploying:
```bash
helm install pull-secret-adapter ./charts/pull-secret \
  --namespace hyperfleet-system \
  --dry-run --debug
```

## Troubleshooting

### View rendered templates
```bash
helm template pull-secret-adapter ./charts/pull-secret
```

### Check deployment issues
```bash
kubectl describe deployment pull-secret-adapter -n hyperfleet-system
kubectl get events -n hyperfleet-system --sort-by='.lastTimestamp'
```

### Authentication errors

Verify Workload Identity:
```bash
# Check ServiceAccount
kubectl get sa -n hyperfleet-system

# Verify IAM binding (using principalSet)
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:principalSet://"
```

## Development

### Linting

Lint the chart:
```bash
helm lint ./charts/pull-secret
```

### Testing

Test template rendering:
```bash
helm template test-release ./charts/pull-secret --debug
```

### Packaging

Package the chart:
```bash
helm package ./charts/pull-secret
```

## References

- [Helm Documentation](https://helm.sh/docs/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [HyperFleet Chart](https://github.com/openshift-hyperfleet/hyperfleet-chart)
- [Adapter Framework Pattern](https://github.com/openshift-hyperfleet/adapter-validation-gcp)
