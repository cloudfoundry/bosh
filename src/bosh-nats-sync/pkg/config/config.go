package config

import (
	"fmt"
	"log/slog"
	"os"

	"gopkg.in/yaml.v3"
)

type DirectorConfig struct {
	URL                    string `yaml:"url"`
	User                   string `yaml:"user"`
	Password               string `yaml:"password"`
	ClientID               string `yaml:"client_id"`
	ClientSecret           string `yaml:"client_secret"`
	CACert                 string `yaml:"ca_cert"`
	DirectorSubjectFile    string `yaml:"director_subject_file"`
	HMSubjectFile          string `yaml:"hm_subject_file"`
	ConnectionWaitTimeout  int    `yaml:"connection_wait_timeout"`
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

	return &cfg, nil
}

func NewLogger(cfg *Config) *slog.Logger {
	var handler slog.Handler
	opts := &slog.HandlerOptions{Level: slog.LevelInfo}

	if cfg.LogFile != "" {
		f, err := os.OpenFile(cfg.LogFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err == nil {
			handler = slog.NewTextHandler(f, opts)
			return slog.New(handler)
		}
	}

	handler = slog.NewTextHandler(os.Stdout, opts)
	return slog.New(handler)
}
