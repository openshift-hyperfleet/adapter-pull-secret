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
  --set env.gcpProjectId=my-project \
  --set env.clusterId=my-cluster-123 \
  --set env.pullSecretData='{"auths":{...}}' \
  --set image.tag=latest
```

### Using a Values File

Create a custom values file (`my-values.yaml`):

```yaml
env:
  gcpProjectId: "my-gcp-project"
  clusterId: "my-cluster-123"
  secretName: "hyperfleet-my-cluster-123-pull-secret"
  pullSecretData: '{"auths":{"registry.example.com":{"auth":"...","email":"user@example.com"}}}'

serviceAccount:
  gcpServiceAccount: "my-service-account@my-project.iam.gserviceaccount.com"

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

## Configuration

The following table lists the configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Kubernetes namespace | `hyperfleet-system` |
| `job.name` | Job name | `pullsecret-job` |
| `job.backoffLimit` | Number of retries on failure | `3` |
| `job.ttlSecondsAfterFinished` | Cleanup delay after completion | `3600` (1 hour) |
| `image.repository` | Container image repository | `quay.io/hyperfleet/pull-secret` |
| `image.tag` | Container image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `serviceAccount.name` | Kubernetes ServiceAccount name | `pullsecret-adapter` |
| `serviceAccount.gcpServiceAccount` | GCP service account for Workload Identity | `your-service-account@your-project.iam.gserviceaccount.com` |
| `env.gcpProjectId` | GCP project ID | `your-gcp-project` |
| `env.clusterId` | Cluster identifier | `your-cluster-id` |
| `env.secretName` | Secret name in GCP Secret Manager | `hyperfleet-your-cluster-id-pull-secret` |
| `env.pullSecretData` | Pull secret JSON data (required) | `{"auths":{...}}` |
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
