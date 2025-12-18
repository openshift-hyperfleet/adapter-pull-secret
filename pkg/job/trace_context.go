package job

import (
	"context"
	"sync"

	logger "github.com/openshift-online/ocm-service-common/pkg/ocmlogger"
)

type (
	contextKey string
)

// Track all the context key. This will be used in logger callback to retrieve all the values
// that are used within the framework.
var (
	set  = make(map[string]struct{})
	lock sync.Mutex
)

// Used for log enrichment.
// We use on-the-fly callback registration so we can avoid it via init() in main.go.
// This allows for the contextual logging to be self-contained within the framework
// so user does not need to worry about callback registration separately.
// The implementation is thread-safe to prevent concurrent access to `set` and `logger.RegisterExtraDataCallback`.

// AddTraceContext adds a key-value pair to the context for tracing and logging purposes.
// It registers a callback for the key on first use and returns the enriched context.
func AddTraceContext(ctx context.Context, key string, value string) context.Context {
	lock.Lock()
	defer lock.Unlock()

	if _, exists := set[key]; !exists {
		set[key] = struct{}{}
		// Register callback once only
		logger.RegisterExtraDataCallback(key, func(ctx context.Context) any {
			return ctx.Value(contextKey(key))
		})
	}
	return context.WithValue(ctx, contextKey(key), value)
}
