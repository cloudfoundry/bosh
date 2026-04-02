package config_test

import (
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Config", func() {
	Describe("Load", func() {
		Context("with a valid configuration", func() {
			It("parses the sample config", func() {
				yaml := `
http:
  port: 25930
mbus:
  endpoint: nats://127.0.0.1:4222
  user: test-user
  password: test-password
  server_ca_path: test-ca-path
  client_certificate_path: test-certificate-path
  client_private_key_path: test-private_key-path
director:
  endpoint: http://127.0.0.1:25555
intervals:
  poll_director: 60
  poll_grace_period: 30
  log_stats: 60
  analyze_agents: 60
  agent_timeout: 60
  rogue_agent_alert: 120
  prune_events: 30
plugins:
  - name: logger
    events:
      - alert
      - heartbeat
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.HTTP.Port).To(Equal(25930))
				Expect(cfg.Mbus.Endpoint).To(Equal("nats://127.0.0.1:4222"))
				Expect(cfg.Mbus.User).To(Equal("test-user"))
				Expect(cfg.Mbus.Password).To(Equal("test-password"))
				Expect(cfg.Director.Endpoint).To(Equal("http://127.0.0.1:25555"))
				Expect(cfg.Plugins).To(HaveLen(1))
				Expect(cfg.Plugins[0].Name).To(Equal("logger"))
				Expect(cfg.Plugins[0].Events).To(ConsistOf("alert", "heartbeat"))
			})

			It("parses plugin config with executable field", func() {
				yaml := `
director:
  endpoint: http://127.0.0.1:25555
plugins:
  - name: resurrector
    executable: /var/vcap/packages/health_monitor/bin/hm-resurrector
    events:
      - alert
    options:
      minimum_down_jobs: 5
      percent_threshold: 0.2
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.Plugins[0].Executable).To(Equal("/var/vcap/packages/health_monitor/bin/hm-resurrector"))
				Expect(cfg.Plugins[0].Options["minimum_down_jobs"]).To(Equal(5))
				Expect(cfg.Plugins[0].Options["percent_threshold"]).To(Equal(0.2))
			})
		})

		Context("without intervals", func() {
			It("sets default for prune_events", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.PruneEvents).To(Equal(30))
			})

			It("sets default for poll_director", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.PollDirector).To(Equal(60))
			})

			It("sets default for poll_grace_period", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.PollGracePeriod).To(Equal(30))
			})

			It("sets default for log_stats", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.LogStats).To(Equal(60))
			})

			It("sets default for analyze_agents", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.AnalyzeAgents).To(Equal(60))
			})

			It("sets default for agent_timeout", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.AgentTimeout).To(Equal(60))
			})

			It("sets default for rogue_agent_alert", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.RogueAgentAlert).To(Equal(120))
			})

			It("sets default for analyze_instances", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.AnalyzeInstances).To(Equal(60))
			})

			It("sets default for resurrection_config", func() {
				cfg := loadMinimal()
				Expect(cfg.Intervals.ResurrectionConfig).To(Equal(60))
			})
		})

		Context("with http config", func() {
			It("sets http port", func() {
				yaml := `
director:
  endpoint: http://127.0.0.1:25555
http:
  port: 1234
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.HTTP.Port).To(Equal(1234))
			})
		})

		Context("with event_mbus", func() {
			It("sets event_mbus", func() {
				yaml := `
director:
  endpoint: http://127.0.0.1:25555
event_mbus:
  endpoint: nats://127.0.0.1:4333
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.EventMbus).NotTo(BeNil())
				Expect(cfg.EventMbus.Endpoint).To(Equal("nats://127.0.0.1:4333"))
			})
		})

		Context("without event_mbus", func() {
			It("does not set event_mbus", func() {
				cfg := loadMinimal()
				Expect(cfg.EventMbus).To(BeNil())
			})
		})

		Context("with loglevel", func() {
			It("sets loglevel", func() {
				yaml := `
director:
  endpoint: http://127.0.0.1:25555
loglevel: debug
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.Loglevel).To(Equal("debug"))
			})
		})

		Context("with plugins", func() {
			It("sets plugins", func() {
				yaml := `
director:
  endpoint: http://127.0.0.1:25555
plugins:
  - name: plugin1
    events:
      - alert
  - name: plugin2
    events:
      - heartbeat
`
				cfg, err := config.Load([]byte(yaml))
				Expect(err).NotTo(HaveOccurred())
				Expect(cfg.Plugins).To(HaveLen(2))
				Expect(cfg.Plugins[0].Name).To(Equal("plugin1"))
				Expect(cfg.Plugins[1].Name).To(Equal("plugin2"))
			})
		})

		Context("with an invalid configuration", func() {
			It("returns error for missing director endpoint", func() {
				yaml := `
http:
  port: 25930
`
				_, err := config.Load([]byte(yaml))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("director endpoint is required"))
			})

			It("returns error for invalid YAML", func() {
				_, err := config.Load([]byte("not: [valid: yaml"))
				Expect(err).To(HaveOccurred())
			})
		})
	})
})

func loadMinimal() *config.Config {
	yaml := `
director:
  endpoint: http://127.0.0.1:25555
`
	cfg, err := config.Load([]byte(yaml))
	Expect(err).NotTo(HaveOccurred())
	return cfg
}
