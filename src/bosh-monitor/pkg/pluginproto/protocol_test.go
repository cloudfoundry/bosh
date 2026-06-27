package pluginproto_test

import (
	"bufio"
	"bytes"
	"encoding/json"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Protocol", func() {
	Describe("Envelope serialization", func() {
		It("writes and reads init envelope", func() {
			env := pluginproto.NewInitEnvelope(map[string]interface{}{
				"host": "localhost",
				"port": 1234,
			})

			var buf bytes.Buffer
			err := pluginproto.WriteEnvelope(&buf, env)
			Expect(err).NotTo(HaveOccurred())

			scanner := bufio.NewScanner(&buf)
			readEnv, err := pluginproto.ReadEnvelope(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(readEnv.Type).To(Equal("init"))
			Expect(readEnv.Options["host"]).To(Equal("localhost"))
		})

		It("writes and reads event envelope", func() {
			event := &pluginproto.EventData{
				Kind:       "alert",
				ID:         "alert-1",
				Severity:   2,
				Title:      "Test Alert",
				Deployment: "dep-1",
			}
			env := pluginproto.NewEventEnvelope(event)

			var buf bytes.Buffer
			err := pluginproto.WriteEnvelope(&buf, env)
			Expect(err).NotTo(HaveOccurred())

			scanner := bufio.NewScanner(&buf)
			readEnv, err := pluginproto.ReadEnvelope(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(readEnv.Type).To(Equal("event"))
			Expect(readEnv.Event.Kind).To(Equal("alert"))
			Expect(readEnv.Event.ID).To(Equal("alert-1"))
			Expect(readEnv.Event.Severity).To(Equal(2))
		})

		It("writes and reads shutdown envelope", func() {
			env := pluginproto.NewShutdownEnvelope()

			var buf bytes.Buffer
			pluginproto.WriteEnvelope(&buf, env)

			scanner := bufio.NewScanner(&buf)
			readEnv, _ := pluginproto.ReadEnvelope(scanner)
			Expect(readEnv.Type).To(Equal("shutdown"))
		})

		It("writes and reads http_response envelope", func() {
			env := pluginproto.NewHTTPResponseEnvelope("req-1", 200, `{"status":"ok"}`)

			var buf bytes.Buffer
			pluginproto.WriteEnvelope(&buf, env)

			scanner := bufio.NewScanner(&buf)
			readEnv, _ := pluginproto.ReadEnvelope(scanner)
			Expect(readEnv.Type).To(Equal("http_response"))
			Expect(readEnv.ID).To(Equal("req-1"))
			Expect(readEnv.Status).To(Equal(200))
			Expect(readEnv.Body).To(Equal(`{"status":"ok"}`))
		})
	})

	Describe("Command serialization", func() {
		It("writes and reads ready command", func() {
			cmd := pluginproto.NewReadyCommand()

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, err := pluginproto.ReadCommand(scanner)
			Expect(err).NotTo(HaveOccurred())
			Expect(readCmd.Cmd).To(Equal("ready"))
		})

		It("writes and reads error command", func() {
			cmd := pluginproto.NewErrorCommand("something broke")

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, _ := pluginproto.ReadCommand(scanner)
			Expect(readCmd.Cmd).To(Equal("error"))
			Expect(readCmd.Message).To(Equal("something broke"))
		})

		It("writes and reads emit_alert command", func() {
			cmd := pluginproto.NewEmitAlertCommand(map[string]interface{}{
				"severity": 4,
				"title":    "Test",
			})

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, _ := pluginproto.ReadCommand(scanner)
			Expect(readCmd.Cmd).To(Equal("emit_alert"))
			Expect(readCmd.Alert["title"]).To(Equal("Test"))
		})

		It("writes and reads log command", func() {
			cmd := pluginproto.NewLogCommand("info", "hello world")

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, _ := pluginproto.ReadCommand(scanner)
			Expect(readCmd.Cmd).To(Equal("log"))
			Expect(readCmd.Level).To(Equal("info"))
			Expect(readCmd.Message).To(Equal("hello world"))
		})

		It("writes and reads http_request command", func() {
			cmd := pluginproto.NewHTTPRequestCommand("req-1", "PUT", "/deployments/dep-1/scan_and_fix",
				map[string]string{"Content-Type": "application/json"}, `{"jobs":{}}`, true)

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, _ := pluginproto.ReadCommand(scanner)
			Expect(readCmd.Cmd).To(Equal("http_request"))
			Expect(readCmd.ID).To(Equal("req-1"))
			Expect(readCmd.Method).To(Equal("PUT"))
			Expect(readCmd.URL).To(Equal("/deployments/dep-1/scan_and_fix"))
			Expect(readCmd.UseDirectorAuth).To(BeTrue())
		})

		It("writes and reads http_get command", func() {
			cmd := pluginproto.NewHTTPGetCommand("req-2", "/tasks?deployment=dep-1", true)

			var buf bytes.Buffer
			pluginproto.WriteCommand(&buf, cmd)

			scanner := bufio.NewScanner(&buf)
			readCmd, _ := pluginproto.ReadCommand(scanner)
			Expect(readCmd.Cmd).To(Equal("http_get"))
			Expect(readCmd.ID).To(Equal("req-2"))
			Expect(readCmd.URL).To(Equal("/tasks?deployment=dep-1"))
		})
	})

	Describe("JSON round-trip", func() {
		It("preserves all fields through marshal/unmarshal", func() {
			original := &pluginproto.Envelope{
				Type: "event",
				Event: &pluginproto.EventData{
					Kind:       "heartbeat",
					ID:         "hb-1",
					Timestamp:  1234567890,
					Deployment: "dep-1",
					AgentID:    "agent-1",
					Job:        "web",
					Index:      "0",
					InstanceID: "inst-1",
					JobState:   "running",
					Teams:      []string{"team-1"},
					Metrics: []pluginproto.MetricData{
						{Name: "cpu.user", Value: "10", Timestamp: 1234567890, Tags: map[string]string{"job": "web"}},
					},
				},
			}

			data, err := json.Marshal(original)
			Expect(err).NotTo(HaveOccurred())

			var parsed pluginproto.Envelope
			Expect(json.Unmarshal(data, &parsed)).To(Succeed())
			Expect(parsed.Type).To(Equal("event"))
			Expect(parsed.Event.Kind).To(Equal("heartbeat"))
			Expect(parsed.Event.Metrics).To(HaveLen(1))
			Expect(parsed.Event.Metrics[0].Name).To(Equal("cpu.user"))
			Expect(parsed.Event.Teams).To(ConsistOf("team-1"))
		})
	})

	Describe("Edge cases", func() {
		It("handles malformed JSON gracefully", func() {
			scanner := bufio.NewScanner(bytes.NewReader([]byte("not json\n")))
			_, err := pluginproto.ReadCommand(scanner)
			Expect(err).To(HaveOccurred())
		})

		It("handles empty input", func() {
			scanner := bufio.NewScanner(bytes.NewReader([]byte{}))
			_, err := pluginproto.ReadCommand(scanner)
			Expect(err).To(HaveOccurred())
		})
	})
})
