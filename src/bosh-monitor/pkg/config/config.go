package config

import (
	"errors"
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	HTTP      HTTPConfig       `yaml:"http" json:"http"`
	Mbus      MbusConfig       `yaml:"mbus" json:"mbus"`
	Director  DirectorConfig   `yaml:"director" json:"director"`
	Intervals IntervalsConfig  `yaml:"intervals" json:"intervals"`
	Logfile   string           `yaml:"logfile" json:"logfile"`
	Loglevel  string           `yaml:"loglevel" json:"loglevel"`
	Plugins   []PluginConfig   `yaml:"plugins" json:"plugins"`
	EventMbus *EventMbusConfig `yaml:"event_mbus,omitempty" json:"event_mbus,omitempty"`
}

type HTTPConfig struct {
	Port int `yaml:"port" json:"port"`
	// Host is the IP address or hostname the HTTP server binds to.
	// Defaults to "127.0.0.1" (loopback-only, matching the Ruby implementation).
	// Override for integration testing against non-loopback addresses.
	Host string `yaml:"host,omitempty" json:"host,omitempty"`
}

type MbusConfig struct {
	Endpoint              string `yaml:"endpoint" json:"endpoint"`
	User                  string `yaml:"user,omitempty" json:"user,omitempty"`
	Password              string `yaml:"password,omitempty" json:"password,omitempty"`
	ServerCAPath          string `yaml:"server_ca_path" json:"server_ca_path"`
	ClientCertificatePath string `yaml:"client_certificate_path" json:"client_certificate_path"`
	ClientPrivateKeyPath  string `yaml:"client_private_key_path" json:"client_private_key_path"`
	ConnectionWaitTimeout int    `yaml:"connection_wait_timeout,omitempty" json:"connection_wait_timeout,omitempty"`
}

type DirectorConfig struct {
	Endpoint       string `yaml:"endpoint" json:"endpoint"`
	User           string `yaml:"user,omitempty" json:"user,omitempty"`
	Password       string `yaml:"password,omitempty" json:"password,omitempty"`
	ClientID       string `yaml:"client_id,omitempty" json:"client_id,omitempty"`
	ClientSecret   string `yaml:"client_secret,omitempty" json:"client_secret,omitempty"`
	DirectorCACert string `yaml:"director_ca_cert,omitempty" json:"director_ca_cert,omitempty"`
	UAACACert      string `yaml:"uaa_ca_cert,omitempty" json:"uaa_ca_cert,omitempty"`
	// UAAPublicKey is the PEM-encoded RSA public key used to verify UAA JWT
	// signatures. When non-empty the token's signature is verified after each
	// fetch, mirroring the Ruby UAAToken decode_options behaviour where
	// { pkey: @uaa_public_key, verify: true } is used when a key is present.
	// When empty, signature verification is skipped (the TLS channel already
	// authenticates the token source), matching Ruby's { verify: false } path.
	UAAPublicKey string `yaml:"uaa_public_key,omitempty" json:"uaa_public_key,omitempty"`
}

type IntervalsConfig struct {
	PruneEvents        int `yaml:"prune_events" json:"prune_events"`
	PollDirector       int `yaml:"poll_director" json:"poll_director"`
	PollGracePeriod    int `yaml:"poll_grace_period" json:"poll_grace_period"`
	LogStats           int `yaml:"log_stats" json:"log_stats"`
	AnalyzeAgents      int `yaml:"analyze_agents" json:"analyze_agents"`
	AnalyzeInstances   int `yaml:"analyze_instances" json:"analyze_instances"`
	AgentTimeout       int `yaml:"agent_timeout" json:"agent_timeout"`
	RogueAgentAlert    int `yaml:"rogue_agent_alert" json:"rogue_agent_alert"`
	ResurrectionConfig int `yaml:"resurrection_config" json:"resurrection_config"`
}

type PluginConfig struct {
	Name       string                 `yaml:"name" json:"name"`
	Executable string                 `yaml:"executable,omitempty" json:"executable,omitempty"`
	Events     []string               `yaml:"events" json:"events"`
	Options    map[string]interface{} `yaml:"options,omitempty" json:"options,omitempty"`
}

type EventMbusConfig struct {
	Endpoint string `yaml:"endpoint" json:"endpoint"`
}

func LoadFile(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("cannot load config file '%s': %w", path, err)
	}
	return Load(data)
}

func Load(data []byte) (*Config, error) {
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("cannot parse config: %w", err)
	}
	cfg.applyDefaults()
	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (c *Config) applyDefaults() {
	if c.HTTP.Host == "" {
		c.HTTP.Host = "127.0.0.1"
	}
	if c.Intervals.PruneEvents == 0 {
		c.Intervals.PruneEvents = 30
	}
	if c.Intervals.PollDirector == 0 {
		c.Intervals.PollDirector = 60
	}
	if c.Intervals.PollGracePeriod == 0 {
		c.Intervals.PollGracePeriod = 30
	}
	if c.Intervals.LogStats == 0 {
		c.Intervals.LogStats = 60
	}
	if c.Intervals.AnalyzeAgents == 0 {
		c.Intervals.AnalyzeAgents = 60
	}
	if c.Intervals.AnalyzeInstances == 0 {
		c.Intervals.AnalyzeInstances = 60
	}
	if c.Intervals.AgentTimeout == 0 {
		c.Intervals.AgentTimeout = 60
	}
	if c.Intervals.RogueAgentAlert == 0 {
		c.Intervals.RogueAgentAlert = 120
	}
	if c.Intervals.ResurrectionConfig == 0 {
		c.Intervals.ResurrectionConfig = 60
	}
}

func (c *Config) validate() error {
	var errs []error

	// HTTP
	if c.HTTP.Port <= 0 || c.HTTP.Port > 65535 {
		errs = append(errs, fmt.Errorf("http.port must be between 1 and 65535 (got %d)", c.HTTP.Port))
	}

	// NATS mbus
	if c.Mbus.Endpoint == "" {
		errs = append(errs, errors.New("mbus.endpoint is required"))
	}
	if c.Mbus.ServerCAPath == "" {
		errs = append(errs, errors.New("mbus.server_ca_path is required"))
	}
	if c.Mbus.ClientCertificatePath == "" {
		errs = append(errs, errors.New("mbus.client_certificate_path is required"))
	}
	if c.Mbus.ClientPrivateKeyPath == "" {
		errs = append(errs, errors.New("mbus.client_private_key_path is required"))
	}

	// Director
	if c.Director.Endpoint == "" {
		errs = append(errs, errors.New("director.endpoint is required"))
	}

	// Intervals (all must be positive after defaults are applied)
	if c.Intervals.PruneEvents <= 0 {
		errs = append(errs, fmt.Errorf("intervals.prune_events must be positive (got %d)", c.Intervals.PruneEvents))
	}
	if c.Intervals.PollDirector <= 0 {
		errs = append(errs, fmt.Errorf("intervals.poll_director must be positive (got %d)", c.Intervals.PollDirector))
	}
	if c.Intervals.PollGracePeriod <= 0 {
		errs = append(errs, fmt.Errorf("intervals.poll_grace_period must be positive (got %d)", c.Intervals.PollGracePeriod))
	}
	if c.Intervals.LogStats <= 0 {
		errs = append(errs, fmt.Errorf("intervals.log_stats must be positive (got %d)", c.Intervals.LogStats))
	}
	if c.Intervals.AnalyzeAgents <= 0 {
		errs = append(errs, fmt.Errorf("intervals.analyze_agents must be positive (got %d)", c.Intervals.AnalyzeAgents))
	}
	if c.Intervals.AnalyzeInstances <= 0 {
		errs = append(errs, fmt.Errorf("intervals.analyze_instances must be positive (got %d)", c.Intervals.AnalyzeInstances))
	}
	if c.Intervals.AgentTimeout <= 0 {
		errs = append(errs, fmt.Errorf("intervals.agent_timeout must be positive (got %d)", c.Intervals.AgentTimeout))
	}
	if c.Intervals.RogueAgentAlert <= 0 {
		errs = append(errs, fmt.Errorf("intervals.rogue_agent_alert must be positive (got %d)", c.Intervals.RogueAgentAlert))
	}
	if c.Intervals.ResurrectionConfig <= 0 {
		errs = append(errs, fmt.Errorf("intervals.resurrection_config must be positive (got %d)", c.Intervals.ResurrectionConfig))
	}

	// Plugins
	for i, p := range c.Plugins {
		if p.Name == "" {
			errs = append(errs, fmt.Errorf("plugins[%d].name is required", i))
		}
	}

	if len(errs) > 0 {
		return fmt.Errorf("invalid config:\n%w", errors.Join(errs...))
	}
	return nil
}
