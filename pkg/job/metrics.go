package job

import (
	"context"
	logger "github.com/openshift-online/ocm-service-common/pkg/ocmlogger"
	"sync"
)

type MetricsReporter interface {
	Report(metricsCollector *MetricsCollector)
}

var mutex sync.Mutex

// MetricsCollector uses locking to ensure we get point-in-time snapshot of the whole data. This snapshot data will be
// then used to report metrics.
type MetricsCollector struct {
	jobName     string
	taskTotal   uint32
	taskSuccess uint32
	taskFailed  uint32
}

func NewMetricsCollector(jobName string) *MetricsCollector {
	return &MetricsCollector{jobName: jobName}
}

// This method does not need to be thread-safe
func (m *MetricsCollector) SetTaskTotal(total uint32) {
	m.taskTotal = total
}
func (m *MetricsCollector) IncTaskSuccess() {
	mutex.Lock()
	m.taskSuccess++
	mutex.Unlock()
}
func (m *MetricsCollector) IncTaskFailed() {
	mutex.Lock()
	m.taskFailed++
	mutex.Unlock()
}

func (m *MetricsCollector) Snapshot() MetricsCollector {
	mutex.Lock()
	defer mutex.Unlock()

	return MetricsCollector{
		jobName:     m.jobName,
		taskTotal:   m.taskTotal,
		taskSuccess: m.taskSuccess,
		taskFailed:  m.taskFailed,
	}

}

type StdoutReporter struct {
}

func (r StdoutReporter) Report(metricsCollector *MetricsCollector) {
	// use snapshot for point-in-time data
	snapshot := metricsCollector.Snapshot()
	logger.NewOCMLogger(context.Background()).Contextual().Info("Printing metrics to STDOUT", "task_total", snapshot.taskTotal, "task_success", snapshot.taskSuccess, "task_failed", snapshot.taskFailed)
}

func NewStdoutReporter() MetricsReporter {
	return StdoutReporter{}
}
