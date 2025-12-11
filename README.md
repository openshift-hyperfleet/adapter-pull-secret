# HyperFleet MVP - Pull Secret Job

This MVP demonstrates the Pull Secret Job that stores OpenShift cluster pull secrets in Google Cloud Platform (GCP) Secret Manager.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Building the Project](#building-the-project)
- [Building Container Images](#building-container-images)
- [Running the Job](#running-the-job)
- [Environment Variables](#environment-variables)
- [Code Architecture](#code-architecture)
- [GCP Secret Manager Integration](#gcp-secret-manager-integration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Pull Secret Job is part of the HyperFleet Pull Secret Adapter (HYPERFLEET-162). It securely stores image pull secrets for OpenShift clusters in the Red Hat GCP Secret Manager using Workload Identity authentication.

**Key Features:**
- ✅ Stores pull secrets in Red Hat GCP Secret Manager
- ✅ Authenticates using Workload Identity (in Kubernetes) or ADC (local development)
- ✅ Structured JSON logging with operation metrics
- ✅ Retry logic with exponential backoff and jitter
- ✅ Idempotent operations (safe to re-run)
- ✅ Pull secret validation (Dockercfg JSON format)
- ✅ Labels for tracking (managed-by, cluster-id, adapter, etc.)

---

## Prerequisites

### 1. Google Cloud SDK

Install the Google Cloud SDK:
```bash
# Verify installation
gcloud --version
```

### 2. Authentication

**IMPORTANT:** You must authenticate with Google Cloud before running the job locally.

```bash
# Authenticate with your Google account
gcloud auth application-default login

# (Optional) Set quota project
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

This creates Application Default Credentials (ADC) that the Secret Manager client uses for authentication.

### 3. GCP Project Setup

Ensure your GCP project has:
- Secret Manager API enabled
- Appropriate IAM permissions for your account

**Check API status:**
```bash
gcloud services list --enabled --project=YOUR_PROJECT_ID | grep secretmanager
```

**Enable Secret Manager API (requires `serviceusage.serviceUsageAdmin` role):**
```bash
gcloud services enable secretmanager.googleapis.com --project=YOUR_PROJECT_ID
```

**Required IAM permissions:**
- `secretmanager.secrets.create` - Create secret resource
- `secretmanager.secrets.get` - Check if secret exists
- `secretmanager.versions.add` - Add new secret version
- `secretmanager.versions.access` - Verify secret data

You need at least the `roles/secretmanager.admin` role on the project.

### 4. Go Environment

- Go 1.23.9 or later
- Dependencies will be downloaded automatically via `go mod`

---

## Building the Project

### Download dependencies

```bash
cd /path/to/mvp
go mod download
```

### Build the binary

```bash
# Using make (recommended)
make binary

# Or using go directly
go build -o pull-secret ./cmd/pull-secret
```

This creates the `pull-secret` executable in the current directory.

---

## Building Container Images

### Prerequisites for Container Builds

- **Podman** or Docker installed
- **Quay.io account** (or other container registry)

### 1. Login to Container Registry

```bash
# Login to quay.io
podman login quay.io
# Username: your-username
# Password: your-password-or-token
```

### 2. Build Container Image

#### Using Makefile (Recommended)

```bash
# Build with automatic git version tag
make image

# Build with custom registry
make image IMAGE_REGISTRY=quay.io/your-username

# Build with specific tag
make image IMAGE_TAG=v1.0.0

# Build for personal development (uses QUAY_USER)
make image-dev QUAY_USER=your-username
```

#### Using Podman Directly

```bash
# Build with specific tag
podman build -t quay.io/your-username/pull-secret:v1.0.0 -f Dockerfile .

# Build with latest tag
podman build -t quay.io/your-username/pull-secret:latest -f Dockerfile .

# Build with multiple tags
podman build \
  -t quay.io/your-username/pull-secret:latest \
  -t quay.io/your-username/pull-secret:v1.0.0 \
  -f Dockerfile .
```

### 3. Push Container Image

#### Using Makefile (Recommended)

```bash
# Build and push with git version
make image-push

# Build and push with specific tag
make image-push IMAGE_TAG=v1.0.0

# Build and push to personal Quay (development workflow)
make image-dev QUAY_USER=your-username
```

#### Using Podman Directly

```bash
# Push specific tag
podman push quay.io/your-username/pull-secret:v1.0.0

# Push latest
podman push quay.io/your-username/pull-secret:latest

# Push all local tags
podman push --all-tags quay.io/your-username/pull-secret
```

### 4. Complete Build and Push Workflow

#### Example 1: Development Build (Personal Quay)

```bash
# Build and push to your personal Quay.io account
# Tag will be automatically generated as dev-<git-commit>
make image-dev QUAY_USER=your-username

# Example output:
# Building dev image quay.io/your-username/pull-secret:dev-f1bf914...
# Pushing dev image quay.io/your-username/pull-secret:dev-f1bf914...
```

#### Example 2: Release Build (Official Registry)

```bash
# Build and push versioned release to official registry
make image-push IMAGE_TAG=v1.0.0

# Example output:
# Building image quay.io/openshift-hyperfleet/pull-secret:v1.0.0...
# Pushing image quay.io/openshift-hyperfleet/pull-secret:v1.0.0...
```

#### Example 3: Manual Multi-Tag Push

```bash
# Build with multiple tags
podman build \
  -t quay.io/your-username/pull-secret:latest \
  -t quay.io/your-username/pull-secret:v1.0.0 \
  -f Dockerfile .

# Push both tags
podman push quay.io/your-username/pull-secret:latest
podman push quay.io/your-username/pull-secret:v1.0.0
```

### 5. Verify and Test Container Image

```bash
# List local images
podman images | grep pull-secret

# Inspect image
podman inspect quay.io/your-username/pull-secret:latest

# Pull from registry (verify it's available)
podman pull quay.io/your-username/pull-secret:latest

# Run the container
podman run --rm \
  -e GCP_PROJECT_ID="your-project-id" \
  -e CLUSTER_ID="cls-test-123" \
  -e SECRET_NAME="hyperfleet-cls-test-123-pull-secret" \
  -e PULL_SECRET_DATA='{"auths":{"registry.redhat.io":{"auth":"dGVzdDp0ZXN0","email":"test@example.com"}}}' \
  quay.io/your-username/pull-secret:latest
```

### 6. Makefile Variables Reference

You can customize the build using these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VERSION` | git describe | Version tag from git |
| `COMMIT` | git rev-parse | Short commit hash |
| `CONTAINER_TOOL` | podman/docker | Container build tool (auto-detected) |
| `IMAGE_REGISTRY` | `quay.io/openshift-hyperfleet` | Container registry |
| `IMAGE_NAME` | `pull-secret` | Image name |
| `IMAGE_TAG` | `$(VERSION)` | Image tag (defaults to git version) |
| `QUAY_USER` | (empty) | Personal Quay username for dev builds |
| `DEV_TAG` | `dev-$(COMMIT)` | Dev image tag |

**Examples:**

```bash
# Use defaults (quay.io/openshift-hyperfleet/pull-secret:<git-version>)
make image

# Build with custom tag
make image IMAGE_TAG=v1.0.0

# Build with custom registry
make image IMAGE_REGISTRY=quay.io/myorg

# Personal development build
make image-dev QUAY_USER=ldornele
# Results in: quay.io/ldornele/pull-secret:dev-f1bf914
```

### 7. Dockerfile Details

The Dockerfile uses a **multi-stage build** for optimization:

- **Stage 1 (Builder):** Uses `registry.access.redhat.com/ubi9/go-toolset:1.23`
  - Downloads dependencies
  - Builds static binary with `CGO_ENABLED=0`

- **Stage 2 (Runtime):** Uses `registry.access.redhat.com/ubi9/ubi-minimal:latest`
  - Minimal attack surface
  - Runs as non-root user (UID 1000)
  - Only contains binary + CA certificates

**Image size:** ~150 MB (compared to ~800+ MB with full Go image)

---

## Running the Job

### Basic Usage

```bash
GCP_PROJECT_ID="your-project-id" \
  CLUSTER_ID="cls-test-123" \
  SECRET_NAME="hyperfleet-cls-test-123-pull-secret" \
  PULL_SECRET_DATA='{"auths":{"registry.redhat.io":{"auth":"dGVzdDp0ZXN0","email":"test@example.com"}}}' \
  ./pull-secret run-job pull-secret
```

### Real-World Example

```bash
GCP_PROJECT_ID="redhat-prod-12345" \
  CLUSTER_ID="cls-abc123" \
  SECRET_NAME="hyperfleet-cls-abc123-pull-secret" \
  PULL_SECRET_DATA='{"auths":{"registry.redhat.io":{"auth":"base64-encoded-credentials","email":"user@redhat.com"},"quay.io":{"auth":"base64-encoded-credentials","email":"user@redhat.com"}}}' \
  ./pull-secret run-job pull-secret
```

### Expected Output

```json
{"cluster_id":"cls-test-123","gcp_project":"your-project-id","level":"info","message":"Starting pull secret storage operation","operation":"start","timestamp":"2025-12-08T13:07:31Z"}
{"cluster_id":"cls-test-123","gcp_project":"your-project-id","level":"info","message":"Successfully initialized Secret Manager client","operation":"client-initialized","timestamp":"2025-12-08T13:07:31Z"}
{"cluster_id":"cls-test-123","gcp_project":"your-project-id","level":"info","message":"Creating new secret: hyperfleet-cls-test-123-pull-secret","operation":"create-secret","timestamp":"2025-12-08T13:07:32Z"}
{"cluster_id":"cls-test-123","duration_ms":2441,"gcp_project":"your-project-id","level":"info","message":"Successfully created secret","operation":"create-secret","timestamp":"2025-12-08T13:07:34Z"}
{"cluster_id":"cls-test-123","gcp_project":"your-project-id","level":"info","message":"Adding secret version with pull secret data","operation":"add-secret-version","timestamp":"2025-12-08T13:07:34Z"}
{"cluster_id":"cls-test-123","duration_ms":2077,"gcp_project":"your-project-id","level":"info","message":"Successfully created secret version","operation":"add-secret-version","timestamp":"2025-12-08T13:07:36Z","version":"projects/123456/secrets/hyperfleet-cls-test-123-pull-secret/versions/1"}
{"cluster_id":"cls-test-123","duration_ms":379,"gcp_project":"your-project-id","level":"info","message":"Verified secret (83 bytes)","operation":"verify-secret","timestamp":"2025-12-08T13:07:36Z"}
{"cluster_id":"cls-test-123","gcp_project":"your-project-id","level":"info","message":"Successfully created/updated pull secret","operation":"completed","timestamp":"2025-12-08T13:07:36Z"}
```

---

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `GCP_PROJECT_ID` | Yes | GCP Project ID where secret will be stored | `redhat-prod-12345` |
| `CLUSTER_ID` | Yes | Unique identifier for the OpenShift cluster | `cls-abc123` |
| `SECRET_NAME` | No* | Name of the secret in GCP Secret Manager | `hyperfleet-cls-abc123-pull-secret` |
| `PULL_SECRET_DATA` | No** | Pull secret in Dockercfg JSON format | `{"auths":{...}}` |

**Notes:**
- *If `SECRET_NAME` is not provided, it will be auto-generated as: `hyperfleet-{CLUSTER_ID}-pull-secret`
- **If `PULL_SECRET_DATA` is not provided, a fake pull secret will be used (for testing only)

### Pull Secret Format

The pull secret must be in **Dockercfg JSON format**:

```json
{
  "auths": {
    "registry.redhat.io": {
      "auth": "base64-encoded-username:password",
      "email": "user@example.com"
    },
    "quay.io": {
      "auth": "base64-encoded-username:password",
      "email": "user@example.com"
    }
  }
}
```

---

## Code Architecture

### Project Structure

```
mvp/
├── cmd/
│   └── pull-secret/
│       ├── main.go              # Entry point
│       └── jobs/
│           └── pull_secret.go   # Pull secret job implementation
├── pkg/
│   └── job/                     # Job framework
├── go.mod                       # Go module dependencies
├── go.sum                       # Dependency checksums
└── README.md                    # This file
```

### Main Components

#### 1. **PullSecretJob** (`jobs/pull_secret.go`)

The main job struct that implements the job framework interface:

```go
type PullSecretJob struct {}

func (pullsecretJob *PullSecretJob) GetTasks() ([]job.Task, error)
func (pullsecretJob *PullSecretJob) GetMetadata() job.Metadata
func (pullsecretJob *PullSecretJob) AddFlags(flags *pflag.FlagSet)
func (pullsecretJob *PullSecretJob) GetWorkerCount() int
```

- **GetTasks()**: Reads environment variables and creates PullSecretTask instances
- **GetMetadata()**: Returns job metadata (name, description)
- **GetWorkerCount()**: Returns number of parallel workers (1 for this job)

#### 2. **PullSecretTask**

The task struct that contains the actual secret data and performs the work:

```go
type PullSecretTask struct {
    PullSecret   string  // Pull secret JSON data
    GCPProjectID string  // GCP project ID
    ClusterID    string  // Cluster identifier
    SecretName   string  // Secret name in GCP
}

func (e PullSecretTask) Process(ctx context.Context) error
```

The `Process()` method executes the following workflow:

1. **Validate configuration** - Ensures all required env vars are present
2. **Validate pull secret format** - Verifies JSON structure
3. **Initialize GCP Secret Manager client** - Creates authenticated client
4. **Create or update secret** - Stores the pull secret in GCP
5. **Verify secret accessibility** - Confirms secret can be read back

#### 3. **Key Functions**

**Configuration & Validation:**
```go
func (e PullSecretTask) validateConfig() error
func validatePullSecret(pullSecretJSON string) error
```

**GCP Secret Manager Operations:**
```go
func (e PullSecretTask) secretExists(ctx context.Context, client *secretmanager.Client) (bool, error)
func (e PullSecretTask) createSecret(ctx context.Context, client *secretmanager.Client) error
func (e PullSecretTask) addSecretVersion(ctx context.Context, client *secretmanager.Client) (string, error)
func (e PullSecretTask) verifySecret(ctx context.Context, client *secretmanager.Client) error
```

**Error Handling & Retry:**
```go
func retryWithBackoff(ctx context.Context, fn func() error, maxRetries int) error
func isRetryable(err error) bool
```

**Logging:**
```go
func logStructured(level, clusterID, gcpProject, operation string, durationMs int64, message, version string)
```

---

## GCP Secret Manager Integration

### SDK Methods Used

The job uses the official GCP Secret Manager Go SDK:

```go
import (
    secretmanager "cloud.google.com/go/secretmanager/apiv1"
    "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)
```

#### 1. **GetSecret** - Check if secret exists

```go
req := &secretmanagerpb.GetSecretRequest{
    Name: "projects/{project}/secrets/{secret}",
}
secret, err := client.GetSecret(ctx, req)
```

Returns `codes.NotFound` if secret doesn't exist.

#### 2. **CreateSecret** - Create secret resource with labels

```go
req := &secretmanagerpb.CreateSecretRequest{
    Parent:   "projects/{project}",
    SecretId: secretName,
    Secret: &secretmanagerpb.Secret{
        Replication: &secretmanagerpb.Replication{
            Replication: &secretmanagerpb.Replication_Automatic_{
                Automatic: &secretmanagerpb.Replication_Automatic{},
            },
        },
        Labels: map[string]string{
            "managed-by":         "hyperfleet",
            "adapter":            "pullsecret",
            "cluster-id":         clusterID,
            "resource-type":      "pull-secret",
            "hyperfleet-version": "v1",
        },
    },
}
secret, err := client.CreateSecret(ctx, req)
```

**Labels applied:**
- `managed-by: hyperfleet` - Identifies HyperFleet-managed secrets
- `adapter: pullsecret` - Identifies the adapter type
- `cluster-id: {cluster-id}` - Links to specific cluster
- `resource-type: pull-secret` - Resource classification
- `hyperfleet-version: v1` - Schema version

#### 3. **AddSecretVersion** - Store pull secret data

```go
req := &secretmanagerpb.AddSecretVersionRequest{
    Parent: "projects/{project}/secrets/{secret}",
    Payload: &secretmanagerpb.SecretPayload{
        Data: []byte(pullSecretJSON),
    },
}
version, err := client.AddSecretVersion(ctx, req)
```

Creates a new immutable version containing the pull secret data.

#### 4. **AccessSecretVersion** - Verify secret accessibility

```go
req := &secretmanagerpb.AccessSecretVersionRequest{
    Name: "projects/{project}/secrets/{secret}/versions/latest",
}
result, err := client.AccessSecretVersion(ctx, req)
data := result.Payload.Data  // The actual secret data
```

Verifies the secret can be read back and returns the payload.

### Authentication Flow

**Local Development:**
```
User runs: gcloud auth application-default login
    ↓
ADC credentials stored at: ~/.config/gcloud/application_default_credentials.json
    ↓
secretmanager.NewClient(ctx) automatically uses ADC
    ↓
API calls authenticated as user account
```

**Production (Kubernetes with Workload Identity):**
```
Job Pod with K8s Service Account: pullsecret-adapter-job
    ↓
Workload Identity binding to GCP Service Account
    ↓
secretmanager.NewClient(ctx) automatically uses Workload Identity
    ↓
API calls authenticated as GCP Service Account
    ↓
Appears in Cloud Audit Logs with GCP SA email
```

### Error Handling & Retry Logic

**Retry Strategy:**
- **Max retries**: 3 attempts
- **Backoff**: Exponential with jitter (1s, 2s, 4s)
- **Jitter**: ±20% to avoid thundering herd

**Retryable Errors:**
- `codes.Unavailable` - Service temporarily unavailable
- `codes.DeadlineExceeded` - Request timeout
- `codes.Internal` - Internal server error
- `codes.ResourceExhausted` - Rate limit exceeded (429)

**Non-Retryable Errors (fail immediately):**
- `codes.PermissionDenied` - Missing IAM permissions
- `codes.InvalidArgument` - Invalid request parameters
- `codes.NotFound` - Resource not found
- `codes.AlreadyExists` - Resource already exists

### Structured Logging

All operations are logged in **structured JSON format**:

```json
{
  "timestamp": "2025-12-08T13:07:31Z",
  "level": "info",
  "cluster_id": "cls-test-123",
  "gcp_project": "redhat-prod-12345",
  "operation": "create-secret",
  "duration_ms": 2441,
  "message": "Successfully created secret",
  "version": "projects/123/secrets/hyperfleet-cls-test-123-pull-secret/versions/1"
}
```

**Log Fields:**
- `timestamp` - ISO 8601 UTC timestamp
- `level` - Log level (info, error)
- `cluster_id` - Cluster identifier
- `gcp_project` - GCP project ID
- `operation` - Operation name (start, create-secret, add-secret-version, etc.)
- `duration_ms` - Operation duration in milliseconds (optional)
- `message` - Human-readable message
- `version` - Secret version (optional)

**Security Note:** Pull secret data is **NEVER** logged to prevent credential exposure.

---

## Verification

### Verify Secret in GCP Console

1. Go to: https://console.cloud.google.com/security/secret-manager?project=YOUR_PROJECT_ID
2. Find secret: `hyperfleet-cls-test-123-pull-secret`
3. Click on the secret to view metadata and labels
4. Click **VERSIONS** tab to see version 1
5. Click **⋮** (three dots) → **View secret value** to see the pull secret data

### Verify Secret via gcloud CLI

```bash
# List secrets with HyperFleet labels
gcloud secrets list \
  --project=YOUR_PROJECT_ID \
  --filter="labels.managed-by=hyperfleet"

# Describe the secret (metadata only)
gcloud secrets describe hyperfleet-cls-test-123-pull-secret \
  --project=YOUR_PROJECT_ID

# View labels
gcloud secrets describe hyperfleet-cls-test-123-pull-secret \
  --project=YOUR_PROJECT_ID \
  --format="table(labels)"

# List versions
gcloud secrets versions list hyperfleet-cls-test-123-pull-secret \
  --project=YOUR_PROJECT_ID

# Access secret data (requires secretmanager.versions.access permission)
gcloud secrets versions access latest \
  --secret=hyperfleet-cls-test-123-pull-secret \
  --project=YOUR_PROJECT_ID
```

### Idempotency Test

Run the job multiple times with the same parameters:

```bash
# First run - creates secret and version 1
./pull-secret run-job pull-secret

# Second run - secret exists, creates version 2
./pull-secret run-job pull-secret

# Third run - secret exists, creates version 3
./pull-secret run-job pull-secret
```

Each run should succeed and create a new version.

---

## Troubleshooting

### Error: "could not find default credentials"

**Problem:** ADC not configured

**Solution:**
```bash
gcloud auth application-default login
```

### Error: "Permission denied on resource project"

**Problem:** Missing IAM permissions or API not enabled

**Solutions:**

1. Check if Secret Manager API is enabled:
```bash
gcloud services list --enabled --project=YOUR_PROJECT_ID | grep secretmanager
```

2. Check your IAM roles:
```bash
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL" \
  --format="table(bindings.role)"
```

3. Request `roles/secretmanager.admin` from project administrator

### Error: "SERVICE_DISABLED"

**Problem:** Secret Manager API not enabled

**Solution:**
```bash
gcloud services enable secretmanager.googleapis.com --project=YOUR_PROJECT_ID
```

Requires `roles/serviceusage.serviceUsageAdmin` role.

### Error: "missing required environment variable"

**Problem:** Required env vars not set

**Solution:** Ensure all required variables are exported:
```bash
export GCP_PROJECT_ID="your-project-id"
export CLUSTER_ID="cls-test-123"
# SECRET_NAME is optional (auto-generated)
# PULL_SECRET_DATA is optional (uses fake data for testing)
```

### Error: "invalid pull secret format"

**Problem:** PULL_SECRET_DATA is not valid Dockercfg JSON

**Solution:** Ensure JSON has required structure:
```json
{"auths":{"registry.redhat.io":{"auth":"...","email":"..."}}}
```

Must have:
- Top-level `auths` key
- At least one registry entry
- Each registry has `auth` field (base64-encoded credentials)

### Build Errors

If you encounter build errors, ensure dependencies are up to date:

```bash
go mod tidy
go mod download
go build ./cmd/pull-secret
```

---

## Performance Benchmarks

Based on actual test runs:

| Operation | Duration | Notes |
|-----------|----------|-------|
| Client initialization | < 1s | Workload Identity token exchange |
| Secret creation | ~2.5s | First-time secret creation |
| Add secret version | ~2s | Adding new version with data |
| Verify secret | ~400ms | Reading back secret data |
| **Total (first run)** | **~5s** | Complete workflow |
| **Total (subsequent)** | **~3s** | Secret already exists |

**Resource Usage:**
- Memory: < 50 MB
- CPU: < 100m (0.1 cores)

---

## Production Deployment

In production, this job runs as a Kubernetes Job in the management cluster:

1. **Adapter** creates Kubernetes Job with proper environment variables
2. **Job Pod** runs with `pullsecret-adapter-job` service account
3. **Workload Identity** automatically authenticates to GCP
4. **Job** executes and stores pull secret in RH's GCP project
5. **Logs** are collected and forwarded to observability platform
6. **Job** completes and is cleaned up after retention period

**Security Context (Production):**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

---

## References

- **Epic**: [HYPERFLEET-162](https://issues.redhat.com/browse/HYPERFLEET-162) - Pull Secret Adapter
- **GCP Secret Manager API**: https://cloud.google.com/secret-manager/docs
- **Go Client Library**: https://pkg.go.dev/cloud.google.com/go/secretmanager/apiv1
- **Workload Identity**: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
- **Architecture Documentation**: `/architecture/hyperfleet/components/adapter/PullSecret/GCP/`

---

## License

Copyright © 2025 Red Hat, Inc.
