package jobs

import (
	"context"

	"github.com/spf13/cobra"
	"gitlab.cee.redhat.com/service/hyperfleet/mvp/pkg/job"
)

func NewJobCommand(ctx context.Context) *cobra.Command {

	var jobRegistry = job.NewJobRegistry()

	// Register only the Pull Secret Job
	jobRegistry.AddJob(&PullSecretJob{})

	builder := &job.CommandBuilder{}
	builder.SetContext(ctx)
	builder.SetRegistry(*jobRegistry)
	cmd := builder.Build()

	return cmd
}
