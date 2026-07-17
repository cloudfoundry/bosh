package config

import (
	"fmt"
	"log/slog"
	"os"

	"gopkg.in/yaml.v3"
)

type DirectorConfig struct {
	URL            string `yaml:"url"`
	User           string `yaml:"user"`
	Password       string `yaml:"password"`
	ClientID       string `yaml:"client_id"`
	ClientSecret   string `yaml:"client_secret"`
	DirectorCACert string `yaml:"director_ca_cert"`
	UAACACert      string `yaml:"uaa_ca_cert"`
	// UAAPublicKey is the PEM-encoded RSA public key used to verify UAA JWT
	// signatures. When non-empty the token's RS256 signature is verified after
	// each fetch, mirroring the Ruby UAAToken decode_options behaviour:
	// { pkey: @uaa_public_key, verify: true }.
	// When empty, signature verification is skipped (the TLS channel already
	// authenticates the token source), matching Ruby's { verify: false } path.
	UAAPublicKey          string `yaml:"uaa_public_key"`
	DirectorSubjectFile   string `yaml:"director_subject_file"`
	HMSubjectFile         string `yaml:"hm_subject_file"`
	ConnectionWaitTimeout int    `yaml:"connection_wait_timeout"`
}

type IntervalsConfig struct {
	PollUserSync int `yaml:"poll_user_sync"`
}

type NATSConfig struct {
	ConfigFilePath       string `yaml:"config_file_path"`
	NATSServerExecutable string `yaml:"nats_server_executable"`
	NATSServerPIDFile    string `yaml:"nats_server_pid_file"`
}

type Config struct {
	Director  DirectorConfig  `yaml:"director"`
	Intervals IntervalsConfig `yaml:"intervals"`
	NATS      NATSConfig      `yaml:"nats"`
	LogFile   string          `yaml:"logfile"`
}

func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("cannot load config file at '%s': %w", path, err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("incorrect file format in '%s': %w", path, err)
	}

	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("invalid config '%s': %w", path, err)
	}

	return &cfg, nil
}

func (c *Config) validate() error {
	if c.Intervals.PollUserSync <= 0 {
		return fmt.Errorf("intervals.poll_user_sync must be a positive integer, got %d", c.Intervals.PollUserSync)
	}
	if c.Director.URL == "" {
		return fmt.Errorf("director.url must be set")
	}
	if c.NATS.ConfigFilePath == "" {
		return fmt.Errorf("nats.config_file_path must be set")
	}
	if c.NATS.NATSServerExecutable == "" {
		return fmt.Errorf("nats.nats_server_executable must be set")
	}
	if c.NATS.NATSServerPIDFile == "" {
		return fmt.Errorf("nats.nats_server_pid_file must be set")
	}
	return nil
}

func NewLogger(cfg *Config) *slog.Logger {
	opts := &slog.HandlerOptions{Level: slog.LevelInfo}

	if cfg != nil && cfg.LogFile != "" {
		f, err := os.OpenFile(cfg.LogFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err == nil {
			return slog.New(slog.NewTextHandler(f, opts))
		}
	}

	return slog.New(slog.NewTextHandler(os.Stdout, opts))
}
