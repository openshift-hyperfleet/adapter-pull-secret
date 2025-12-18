// Package config provides configuration types and utilities for job execution.
package config

import "github.com/spf13/pflag"

// JobConfig holds the configuration options for job execution.
type JobConfig struct {
	DryRun      bool `json:"dry_run"`
	WorkerCount int  `json:"worker_count"`
}

// NewJobConfig creates a new JobConfig with default values.
func NewJobConfig() *JobConfig {
	return &JobConfig{
		DryRun:      true,
		WorkerCount: 1,
	}
}

// AddFlags registers the job configuration flags with the provided flag set.
func (c *JobConfig) AddFlags(fs *pflag.FlagSet) {
	fs.BoolVar(&c.DryRun, "dry-run", c.DryRun, "Show what would be changed by a run of this script.")
	fs.IntVar(&c.WorkerCount, "worker-count", c.WorkerCount, "Number of concurrent workers.")
}
