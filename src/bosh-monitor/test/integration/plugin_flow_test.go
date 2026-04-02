package integration_test

import (
	"bufio"
	"encoding/json"
	"log/slog"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginhost"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/processor"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("End-to-End Plugin Flow", func() {
	var (
		host   *pluginhost.Host
		ep     *processor.EventProcessor
		logger *slog.Logger
	)

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelDebug}))
	})

	Describe("EventProcessor -> PluginHost -> Plugin Binary", func() {
		It("dispatches events through the plugin protocol", func() {
			host = pluginhost.NewHost(logger, nil, nil)
			ep = processor.NewEventProcessor(host, logger)
			host.SetEmitter(ep)

			alert := events.NewAlert(map[string]interface{}{
				"id":         "test-alert-1",
				"severity":   2,
				"title":      "Integration Test Alert",
				"summary":    "Testing end-to-end flow",
				"source":     "integration-test",
				"deployment": "test-deployment",
				"created_at": time.Now().Unix(),
			})

			host.Dispatch("alert", alert)
		})
	})

	Describe("Plugin protocol round-trip", func() {
		It("serializes events through the full envelope lifecycle", func() {
			alert := events.NewAlert(map[string]interface{}{
				"id":         "proto-test-1",
				"severity":   3,
				"title":      "Protocol Test",
				"summary":    "Testing protocol",
				"source":     "test",
				"deployment": "dep-1",
				"created_at": time.Now().Unix(),
			})

			eventData := &pluginproto.EventData{
				Kind:       alert.Kind(),
				ID:         alert.ID(),
				Severity:   alert.Severity,
				Title:      alert.Title,
				Summary:    alert.Summary,
				Source:     alert.Source,
				Deployment: alert.Deployment,
				CreatedAt:  alert.CreatedAt.Unix(),
			}

			env := pluginproto.NewEventEnvelope(eventData)
			data, err := json.Marshal(env)
			Expect(err).NotTo(HaveOccurred())

			var parsed pluginproto.Envelope
			Expect(json.Unmarshal(data, &parsed)).To(Succeed())
			Expect(parsed.Type).To(Equal("event"))
			Expect(parsed.Event.Kind).To(Equal("alert"))
			Expect(parsed.Event.ID).To(Equal("proto-test-1"))
			Expect(parsed.Event.Severity).To(Equal(3))
		})

		It("handles heartbeat events with metrics through the pipeline", func() {
			hb := events.NewHeartbeat(map[string]interface{}{
				"id":          "hb-test-1",
				"timestamp":   time.Now().Unix(),
				"deployment":  "dep-1",
				"agent_id":    "agent-1",
				"job":         "web",
				"index":       "0",
				"instance_id": "inst-1",
				"job_state":   "running",
				"vitals": map[string]interface{}{
					"load": []interface{}{0.5, 0.3, 0.1},
					"cpu":  map[string]interface{}{"user": "15", "sys": "3", "wait": "0"},
					"mem":  map[string]interface{}{"percent": "45", "kb": "2048000"},
					"swap": map[string]interface{}{"percent": "5", "kb": "100000"},
					"disk": map[string]interface{}{
						"system":     map[string]interface{}{"percent": "20", "inode_percent": "3"},
						"ephemeral":  map[string]interface{}{"percent": "30", "inode_percent": "4"},
						"persistent": map[string]interface{}{"percent": "40", "inode_percent": "5"},
					},
				},
			})

			Expect(hb.Metrics()).To(HaveLen(15))

			eventData := &pluginproto.EventData{
				Kind:       hb.Kind(),
				ID:         hb.ID(),
				Timestamp:  hb.Timestamp.Unix(),
				Deployment: hb.Deployment,
				AgentID:    hb.AgentID,
				Job:        hb.Job,
				Index:      hb.Index,
				InstanceID: hb.InstanceID,
				JobState:   hb.JobState,
				Vitals:     hb.Vitals,
			}
			for _, m := range hb.HBMetrics {
				eventData.Metrics = append(eventData.Metrics, pluginproto.MetricData{
					Name:      m.Name,
					Value:     m.Value,
					Timestamp: m.Timestamp,
					Tags:      m.Tags,
				})
			}

			env := pluginproto.NewEventEnvelope(eventData)
			data, err := json.Marshal(env)
			Expect(err).NotTo(HaveOccurred())
			Expect(len(data)).To(BeNumerically(">", 0))

			var parsed pluginproto.Envelope
			Expect(json.Unmarshal(data, &parsed)).To(Succeed())
			Expect(parsed.Event.Metrics).To(HaveLen(15))
		})
	})

	Describe("Command handling round-trip", func() {
		It("processes emit_alert commands back through the event processor", func() {
			host = pluginhost.NewHost(logger, nil, nil)
			ep = processor.NewEventProcessor(host, logger)
			host.SetEmitter(ep)

			cmd := pluginproto.NewEmitAlertCommand(map[string]interface{}{
				"id":         "emitted-alert-1",
				"severity":   4,
				"title":      "Emitted Alert",
				"summary":    "Alert emitted by plugin",
				"source":     "test-plugin",
				"deployment": "dep-1",
				"created_at": time.Now().Unix(),
			})

			host.HandleCommand("test-plugin", cmd)
			Expect(ep.EventsCount()).To(Equal(1))
		})
	})

	Describe("PluginHost with config", func() {
		It("handles plugin config with executable and events", func() {
			plugins := []config.PluginConfig{
				{
					Name:       "test-logger",
					Executable: "/nonexistent/hm-logger",
					Events:     []string{"alert", "heartbeat"},
					Options:    map[string]interface{}{"format": "json"},
				},
			}

			host = pluginhost.NewHost(logger, nil, nil)
			err := host.StartPlugins(plugins)
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Protocol envelope reading from scanner", func() {
		It("reads multiple envelopes sequentially", func() {
			pr, pw, _ := os.Pipe()
			defer pr.Close()

			go func() {
				pluginproto.WriteEnvelope(pw, pluginproto.NewInitEnvelope(map[string]interface{}{"key": "val"}))
				pluginproto.WriteEnvelope(pw, pluginproto.NewEventEnvelope(&pluginproto.EventData{Kind: "alert", ID: "a1"}))
				pluginproto.WriteEnvelope(pw, pluginproto.NewShutdownEnvelope())
				pw.Close()
			}()

			scanner := bufio.NewScanner(pr)
			env1, err := pluginproto.ReadEnvelope(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(env1.Type).To(Equal("init"))

			env2, err := pluginproto.ReadEnvelope(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(env2.Type).To(Equal("event"))
			Expect(env2.Event.ID).To(Equal("a1"))

			env3, err := pluginproto.ReadEnvelope(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(env3.Type).To(Equal("shutdown"))
		})
	})
})
