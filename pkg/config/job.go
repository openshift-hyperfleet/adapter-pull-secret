package config

import "github.com/spf13/pflag"

type JobConfig struct {
	DryRun      bool `json:"dry_run"`
	WorkerCount int  `json:"worker_count"`
}

func NewJobConfig() *JobConfig {
	return &JobConfig{
		DryRun:      true,
		WorkerCount: 1,
	}
}

func (c *JobConfig) AddFlags(fs *pflag.FlagSet) {
	fs.BoolVar(&c.DryRun, "dry-run", c.DryRun, "Show what would be changed by a run of this script.")
	fs.IntVar(&c.WorkerCount, "worker-count", c.WorkerCount, "Number of concurrent workers.")
}
