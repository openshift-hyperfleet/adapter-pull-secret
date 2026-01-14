# Multi-stage build for pull-secret-mvp
# Stage 1: Builder
FROM registry.access.redhat.com/ubi9/go-toolset:1.23 AS builder

# Switch to root to set up workspace
USER root

# Set working directory
WORKDIR /workspace

# Copy go mod files
COPY --chown=default:root go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY --chown=default:root . .

# Switch back to default user
USER default

# Build the binary
# CGO_ENABLED=0 for static binary (simplified MVP build)
# -buildvcs=false to avoid VCS stamping errors in CI environments
RUN CGO_ENABLED=0 go build \
    -buildvcs=false \
    -o pull-secret \
    ./cmd/pull-secret

# Stage 2: Runtime
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Install CA certificates for TLS
RUN microdnf install -y ca-certificates && microdnf clean all

# Create non-root user
RUN useradd -u 1000 -m -s /sbin/nologin pullsecret-job

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=1000:1000 /workspace/pull-secret /usr/local/bin/pull-secret

# Set permissions
RUN chmod 755 /usr/local/bin/pull-secret

# Use non-root user
USER 1000

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/pull-secret"]

# Default command (can be overridden)
CMD ["run-job", "pull-secret"]
