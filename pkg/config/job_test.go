package config

import (
	"testing"

	"github.com/spf13/pflag"
)

func TestNewJobConfig(t *testing.T) {
	config := NewJobConfig()

	if config == nil {
		t.Fatal("NewJobConfig() returned nil")
	}

	if !config.DryRun {
		t.Errorf("Expected DryRun to be true by default, got false")
	}

	if config.WorkerCount != 1 {
		t.Errorf("Expected WorkerCount to be 1 by default, got %d", config.WorkerCount)
	}
}

func TestJobConfig_AddFlags(t *testing.T) {
	config := NewJobConfig()
	fs := pflag.NewFlagSet("test", pflag.ContinueOnError)

	config.AddFlags(fs)

	// Verify flags were added
	if fs.Lookup("dry-run") == nil {
		t.Error("Expected 'dry-run' flag to be registered")
	}

	if fs.Lookup("worker-count") == nil {
		t.Error("Expected 'worker-count' flag to be registered")
	}

	// TODO: Add more comprehensive flag parsing tests
}

func TestJobConfig_FlagParsing(t *testing.T) {
	config := NewJobConfig()
	fs := pflag.NewFlagSet("test", pflag.ContinueOnError)

	config.AddFlags(fs)

	// Test parsing custom values
	args := []string{"--dry-run=false", "--worker-count=5"}
	if err := fs.Parse(args); err != nil {
		t.Fatalf("Failed to parse flags: %v", err)
	}

	if config.DryRun {
		t.Errorf("Expected DryRun to be false after parsing, got true")
	}

	if config.WorkerCount != 5 {
		t.Errorf("Expected WorkerCount to be 5 after parsing, got %d", config.WorkerCount)
	}

	// TODO: Add edge case tests (negative worker count, etc.)
}
