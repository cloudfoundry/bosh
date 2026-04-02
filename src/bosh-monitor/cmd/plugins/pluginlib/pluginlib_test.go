package pluginlib_test

import (
	"bytes"
	"context"
	"encoding/json"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Pluginlib", func() {
	Describe("RunWithIO", func() {
		It("handles init/event/shutdown lifecycle", func() {
			var stdin bytes.Buffer
			var stdout bytes.Buffer

			initEnv := pluginproto.NewInitEnvelope(map[string]interface{}{"key": "value"})
			pluginproto.WriteEnvelope(&stdin, initEnv)

			eventEnv := pluginproto.NewEventEnvelope(&pluginproto.EventData{
				Kind: "alert",
				ID:   "alert-1",
			})
			pluginproto.WriteEnvelope(&stdin, eventEnv)

			shutdownEnv := pluginproto.NewShutdownEnvelope()
			pluginproto.WriteEnvelope(&stdin, shutdownEnv)

			var receivedEvents int
			err := pluginlib.RunWithIO(&stdin, &stdout, func(ctx context.Context, opts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
				var parsedOpts map[string]interface{}
				json.Unmarshal(opts, &parsedOpts)
				Expect(parsedOpts["key"]).To(Equal("value"))

				for range events {
					receivedEvents++
				}
				return nil
			})

			Expect(err).NotTo(HaveOccurred())
			Expect(receivedEvents).To(Equal(1))

			Expect(stdout.Len()).To(BeNumerically(">", 0))
			var readyCmd pluginproto.Command
			json.Unmarshal(stdout.Bytes()[:bytes.IndexByte(stdout.Bytes(), '\n')], &readyCmd)
			Expect(readyCmd.Cmd).To(Equal("ready"))
		})

		It("returns error when first envelope is not init", func() {
			var stdin bytes.Buffer
			var stdout bytes.Buffer

			eventEnv := pluginproto.NewEventEnvelope(&pluginproto.EventData{Kind: "alert", ID: "1"})
			pluginproto.WriteEnvelope(&stdin, eventEnv)

			err := pluginlib.RunWithIO(&stdin, &stdout, func(ctx context.Context, opts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
				return nil
			})

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("expected init envelope"))
		})

		It("sends commands written to the cmds channel", func() {
			var stdin bytes.Buffer
			var stdout bytes.Buffer

			pluginproto.WriteEnvelope(&stdin, pluginproto.NewInitEnvelope(nil))

			eventEnv := pluginproto.NewEventEnvelope(&pluginproto.EventData{Kind: "alert", ID: "a1"})
			pluginproto.WriteEnvelope(&stdin, eventEnv)
			pluginproto.WriteEnvelope(&stdin, pluginproto.NewShutdownEnvelope())

			err := pluginlib.RunWithIO(&stdin, &stdout, func(ctx context.Context, opts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
				for env := range events {
					if env.Event != nil {
						cmds <- pluginlib.LogCommand("info", "hello")
					}
				}
				return nil
			})

			Expect(err).NotTo(HaveOccurred())
			output := stdout.String()
			Expect(output).To(ContainSubstring("ready"))
			Expect(output).To(ContainSubstring("hello"))
		})
	})

	Describe("Helper functions", func() {
		It("creates log commands", func() {
			cmd := pluginlib.LogCommand("info", "test message")
			Expect(cmd.Cmd).To(Equal("log"))
			Expect(cmd.Level).To(Equal("info"))
			Expect(cmd.Message).To(Equal("test message"))
		})

		It("creates emit_alert commands", func() {
			cmd := pluginlib.EmitAlertCommand(map[string]interface{}{"severity": 4})
			Expect(cmd.Cmd).To(Equal("emit_alert"))
			Expect(cmd.Alert["severity"]).To(Equal(4))
		})

		It("creates http_request commands", func() {
			cmd := pluginlib.HTTPRequestCommand("req-1", "PUT", "/path", nil, "body")
			Expect(cmd.Cmd).To(Equal("http_request"))
			Expect(cmd.Method).To(Equal("PUT"))
			Expect(cmd.UseDirectorAuth).To(BeTrue())
		})

		It("creates http_get commands", func() {
			cmd := pluginlib.HTTPGetCommand("req-2", "/tasks")
			Expect(cmd.Cmd).To(Equal("http_get"))
			Expect(cmd.URL).To(Equal("/tasks"))
			Expect(cmd.UseDirectorAuth).To(BeTrue())
		})
	})
})
