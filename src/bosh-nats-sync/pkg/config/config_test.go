package config_test

import (
	"log/slog"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/config"
)

var _ = Describe("Config", func() {
	Describe("Load", func() {
		It("parses a valid YAML config file", func() {
			cfg, err := config.Load(filepath.Join("..", "..", "testdata", "sample_config.yml"))
			Expect(err).NotTo(HaveOccurred())

			Expect(cfg.Director.URL).To(Equal("http://127.0.0.1:25555"))
			Expect(cfg.Director.User).To(Equal("admin"))
			Expect(cfg.Director.Password).To(Equal("admin"))
			Expect(cfg.Director.ClientID).To(Equal("client_id"))
			Expect(cfg.Director.ClientSecret).To(Equal("client_secret"))
			Expect(cfg.Director.CACert).To(Equal("ca_cert"))
			Expect(cfg.Director.DirectorSubjectFile).To(Equal("/var/vcap/data/nats/director-subject"))
			Expect(cfg.Director.HMSubjectFile).To(Equal("/var/vcap/data/nats/hm-subject"))
			Expect(cfg.Intervals.PollUserSync).To(Equal(1))
			Expect(cfg.NATS.ConfigFilePath).To(Equal("/var/vcap/data/nats/auth.json"))
			Expect(cfg.NATS.NATSServerExecutable).To(Equal("/var/vcap/packages/nats/bin/nats-server"))
			Expect(cfg.NATS.NATSServerPIDFile).To(Equal("/var/vcap/sys/run/bpm/nats/nats.pid"))
			Expect(cfg.LogFile).To(Equal("/tmp/bosh-nats-sync.log"))
		})

		It("returns an error for a non-existent file", func() {
			_, err := config.Load("/nonexistent/path.yml")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("cannot load config file"))
		})

		It("returns an error for invalid YAML", func() {
			tmpFile, err := os.CreateTemp("", "bad_config_*.yml")
			Expect(err).NotTo(HaveOccurred())
			defer os.Remove(tmpFile.Name())

			_, err = tmpFile.WriteString("{{invalid yaml")
			Expect(err).NotTo(HaveOccurred())
			tmpFile.Close()

			_, err = config.Load(tmpFile.Name())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("incorrect file format"))
		})
	})

	Describe("NewLogger", func() {
		It("creates a logger that writes to the specified log file", func() {
			tmpFile, err := os.CreateTemp("", "nats_log_*.log")
			Expect(err).NotTo(HaveOccurred())
			logPath := tmpFile.Name()
			tmpFile.Close()
			defer os.Remove(logPath)

			cfg := &config.Config{LogFile: logPath}
			logger := config.NewLogger(cfg)

			logger.Info("Test log 1")

			content, err := os.ReadFile(logPath)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(content)).To(ContainSubstring("Test log 1"))
		})

		It("creates a logger at info level", func() {
			tmpFile, err := os.CreateTemp("", "nats_log_*.log")
			Expect(err).NotTo(HaveOccurred())
			logPath := tmpFile.Name()
			tmpFile.Close()
			defer os.Remove(logPath)

			cfg := &config.Config{LogFile: logPath}
			logger := config.NewLogger(cfg)

			Expect(logger.Enabled(nil, slog.LevelInfo)).To(BeTrue())
			Expect(logger.Enabled(nil, slog.LevelDebug)).To(BeFalse())
		})

		It("falls back to stdout when no log file is specified", func() {
			cfg := &config.Config{}
			logger := config.NewLogger(cfg)
			Expect(logger).NotTo(BeNil())
		})
	})
})
