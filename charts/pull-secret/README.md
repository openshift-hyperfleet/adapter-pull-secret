# Pull Secret Adapter Helm Chart

This Helm chart deploys the HyperFleet Pull Secret Adapter as a Kubernetes Job on GKE.

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

3. **Workload Identity configured**
   - Service Account: `your-service-account@your-project.iam.gserviceaccount.com`
   - Workload Pool: `your-project.svc.id.goog`

## Installation

### Quick Start

Deploy with default values:

```bash
helm install pullsecret-job ./charts/pull-secret \
  --namespace hyperfleet-system \
  --create-namespace
```

### Custom Values

Deploy with custom configuration:

```bash
helm install pullsecret-job ./charts/pull-secret \
  --namespace hyperfleet-system \
  --create-namespace \
  --set gcp.projectId=my-project \
  --set cluster.id=my-cluster-123 \
  --set pullSecret.data='{"auths":{...}}' \
  --set image.tag=latest
```

### Using a Values File

Create a custom values file (`my-values.yaml`):

```yaml
gcp:
  projectId: "my-gcp-project"

cluster:
  id: "my-cluster-123"

pullSecret:
  name: "hyperfleet-my-cluster-123-pull-secret"
  data: '{"auths":{"registry.example.com":{"auth":"...","email":"user@example.com"}}}'

serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "my-service-account@my-project.iam.gserviceaccount.com"

image:
  tag: "v1.0.0"
```

Then install:

```bash
helm install pullsecret-job ./charts/pull-secret \
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
  gcp:
    projectId: "my-project"
  cluster:
    id: "my-cluster"
```

## Configuration

The following table lists the configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.image.registry` | Global image registry override (umbrella chart) | `""` |
| `image.registry` | Container image registry | `quay.io/openshift-hyperfleet` |
| `image.repository` | Container image repository | `pull-secret` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | Kubernetes ServiceAccount name | `""` (auto-generated) |
| `serviceAccount.annotations` | ServiceAccount annotations (for Workload Identity) | `{}` |
| `rbac.create` | Create RBAC resources | `true` |
| `job.name` | Job name | `""` (auto-generated) |
| `job.backoffLimit` | Number of retries on failure | `3` |
| `job.ttlSecondsAfterFinished` | Cleanup delay after completion | `3600` (1 hour) |
| `gcp.projectId` | GCP project ID | `""` |
| `cluster.id` | Cluster identifier | `""` |
| `pullSecret.name` | Secret name in GCP Secret Manager | `hyperfleet-{cluster.id}-pull-secret` |
| `pullSecret.data` | Pull secret JSON data (**required**) | `""` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |

## Usage

### Monitoring

Check job status:
```bash
helm status pullsecret-job -n hyperfleet-system
kubectl get job pullsecret-job -n hyperfleet-system
```

View logs:
```bash
kubectl logs -f job/pullsecret-job -n hyperfleet-system
```

### Upgrading

Upgrade the deployment with new values:
```bash
helm upgrade pullsecret-job ./charts/pull-secret \
  --namespace hyperfleet-system \
  --set image.tag=v1.1.0
```

### Uninstalling

Remove the job:
```bash
helm uninstall pullsecret-job -n hyperfleet-system
```

## Dry Run Mode

Test without creating secrets:
```bash
helm install pullsecret-job ./charts/pull-secret \
  --namespace hyperfleet-system \
  --dry-run --debug
```

## Troubleshooting

### View rendered templates
```bash
helm template pullsecret-job ./charts/pull-secret
```

### Check deployment issues
```bash
kubectl describe job pullsecret-job -n hyperfleet-system
kubectl get events -n hyperfleet-system --sort-by='.lastTimestamp'
```

### Authentication errors

Verify Workload Identity binding:
```bash
# Check ServiceAccount
kubectl get sa pullsecret-adapter -n hyperfleet-system -o yaml

# Check GCP IAM binding
gcloud iam service-accounts get-iam-policy \
  your-service-account@your-project.iam.gserviceaccount.com \
  --project=your-project
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
