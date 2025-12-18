package job

import (
	"context"
	"sync"

	logger "github.com/openshift-online/ocm-service-common/pkg/ocmlogger"
)

// MetricsReporter defines the interface for reporting metrics collected during job execution.
type MetricsReporter interface {
	Report(metricsCollector *MetricsCollector)
}

// MetricsCollector uses locking to ensure we get point-in-time snapshot of the whole data. This snapshot data will be
// then used to report metrics.
type MetricsCollector struct {
	mu          sync.Mutex
	jobName     string
	taskTotal   uint32
	taskSuccess uint32
	taskFailed  uint32
}

// NewMetricsCollector creates a new metrics collector for the given job name.
func NewMetricsCollector(jobName string) *MetricsCollector {
	return &MetricsCollector{jobName: jobName}
}

// SetTaskTotal sets the total number of tasks.
func (m *MetricsCollector) SetTaskTotal(total uint32) {
	m.taskTotal = total
}

// IncTaskSuccess increments the successful task counter.
func (m *MetricsCollector) IncTaskSuccess() {
	m.mu.Lock()
	m.taskSuccess++
	m.mu.Unlock()
}

// IncTaskFailed increments the failed task counter.
func (m *MetricsCollector) IncTaskFailed() {
	m.mu.Lock()
	m.taskFailed++
	m.mu.Unlock()
}

// Snapshot returns a point-in-time copy of the metrics collector.
func (m *MetricsCollector) Snapshot() MetricsCollector {
	m.mu.Lock()
	defer m.mu.Unlock()

	return MetricsCollector{
		jobName:     m.jobName,
		taskTotal:   m.taskTotal,
		taskSuccess: m.taskSuccess,
		taskFailed:  m.taskFailed,
	}

}

// StdoutReporter reports metrics to stdout.
type StdoutReporter struct {
}

// Report prints the metrics to stdout using the logger.
func (r StdoutReporter) Report(metricsCollector *MetricsCollector) {
	// use snapshot for point-in-time data
	snapshot := metricsCollector.Snapshot()
	logger.NewOCMLogger(context.Background()).Contextual().Info("Printing metrics to STDOUT", "task_total", snapshot.taskTotal, "task_success", snapshot.taskSuccess, "task_failed", snapshot.taskFailed)
}

// NewStdoutReporter creates a new stdout metrics reporter.
func NewStdoutReporter() MetricsReporter {
	return StdoutReporter{}
}
