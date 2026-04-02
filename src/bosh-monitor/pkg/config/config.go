package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	HTTP      HTTPConfig      `yaml:"http" json:"http"`
	Mbus      MbusConfig      `yaml:"mbus" json:"mbus"`
	Director  DirectorConfig  `yaml:"director" json:"director"`
	Intervals IntervalsConfig `yaml:"intervals" json:"intervals"`
	Logfile   string          `yaml:"logfile" json:"logfile"`
	Loglevel  string          `yaml:"loglevel" json:"loglevel"`
	Plugins   []PluginConfig  `yaml:"plugins" json:"plugins"`
	EventMbus *EventMbusConfig `yaml:"event_mbus,omitempty" json:"event_mbus,omitempty"`
}

type HTTPConfig struct {
	Port int `yaml:"port" json:"port"`
}

type MbusConfig struct {
	Endpoint             string `yaml:"endpoint" json:"endpoint"`
	User                 string `yaml:"user,omitempty" json:"user,omitempty"`
	Password             string `yaml:"password,omitempty" json:"password,omitempty"`
	ServerCAPath         string `yaml:"server_ca_path" json:"server_ca_path"`
	ClientCertificatePath string `yaml:"client_certificate_path" json:"client_certificate_path"`
	ClientPrivateKeyPath string `yaml:"client_private_key_path" json:"client_private_key_path"`
	ConnectionWaitTimeout int   `yaml:"connection_wait_timeout,omitempty" json:"connection_wait_timeout,omitempty"`
}

type DirectorConfig struct {
	Endpoint     string `yaml:"endpoint" json:"endpoint"`
	User         string `yaml:"user,omitempty" json:"user,omitempty"`
	Password     string `yaml:"password,omitempty" json:"password,omitempty"`
	ClientID     string `yaml:"client_id,omitempty" json:"client_id,omitempty"`
	ClientSecret string `yaml:"client_secret,omitempty" json:"client_secret,omitempty"`
	CACert       string `yaml:"ca_cert,omitempty" json:"ca_cert,omitempty"`
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
	if c.Director.Endpoint == "" {
		return fmt.Errorf("director endpoint is required")
	}
	return nil
}
