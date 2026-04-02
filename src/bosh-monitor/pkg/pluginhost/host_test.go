package pluginhost_test

import (
	"log/slog"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginhost"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type fakeEmitter struct {
	alerts []map[string]interface{}
}

func (f *fakeEmitter) Process(kind string, data map[string]interface{}) error {
	f.alerts = append(f.alerts, data)
	return nil
}

type fakeDirector struct {
	lastMethod string
	lastPath   string
}

func (f *fakeDirector) PerformRequestForPlugin(method, path string, headers map[string]string, body string, useDirectorAuth bool) (string, int, error) {
	f.lastMethod = method
	f.lastPath = path
	return `{"status":"ok"}`, 200, nil
}

var _ = Describe("Host", func() {
	var (
		host    *pluginhost.Host
		emitter *fakeEmitter
		dir     *fakeDirector
		logger  *slog.Logger
	)

	BeforeEach(func() {
		emitter = &fakeEmitter{}
		dir = &fakeDirector{}
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		host = pluginhost.NewHost(logger, emitter, dir)
	})

	Describe("HandleCommand", func() {
		It("handles emit_alert commands", func() {
			cmd := &pluginproto.Command{
				Cmd:   "emit_alert",
				Alert: map[string]interface{}{"severity": 4, "title": "Test"},
			}
			host.HandleCommand("test-plugin", cmd)
			Expect(emitter.alerts).To(HaveLen(1))
			Expect(emitter.alerts[0]["title"]).To(Equal("Test"))
		})

		It("handles http_request commands", func() {
			cmd := &pluginproto.Command{
				Cmd:             "http_request",
				ID:              "req-1",
				Method:          "PUT",
				URL:             "/deployments/dep-1/scan_and_fix",
				UseDirectorAuth: true,
			}
			host.HandleCommand("test-plugin", cmd)
			time.Sleep(100 * time.Millisecond)
			Expect(dir.lastMethod).To(Equal("PUT"))
			Expect(dir.lastPath).To(Equal("/deployments/dep-1/scan_and_fix"))
		})

		It("handles http_get commands", func() {
			cmd := &pluginproto.Command{
				Cmd:             "http_get",
				ID:              "req-2",
				URL:             "/tasks",
				UseDirectorAuth: true,
			}
			host.HandleCommand("test-plugin", cmd)
			time.Sleep(100 * time.Millisecond)
			Expect(dir.lastMethod).To(Equal("GET"))
		})

		It("handles log commands", func() {
			cmd := &pluginproto.Command{
				Cmd:     "log",
				Level:   "info",
				Message: "test message",
			}
			host.HandleCommand("test-plugin", cmd)
		})

		It("handles ready commands", func() {
			cmd := &pluginproto.Command{Cmd: "ready"}
			host.HandleCommand("test-plugin", cmd)
		})

		It("handles error commands", func() {
			cmd := &pluginproto.Command{Cmd: "error", Message: "init failed"}
			host.HandleCommand("test-plugin", cmd)
		})
	})

	Describe("Dispatch", func() {
		It("dispatches events to subscribed plugins", func() {
			alert := events.NewAlert(map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test",
				"created_at": time.Now().Unix(),
			})
			host.Dispatch("alert", alert)
		})
	})

	Describe("StartPlugins", func() {
		It("handles missing executable gracefully", func() {
			err := host.StartPlugins([]config.PluginConfig{
				{Name: "nonexistent", Executable: "/nonexistent/binary", Events: []string{"alert"}},
			})
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Shutdown", func() {
		It("shuts down cleanly with no plugins", func() {
			host.Shutdown()
		})
	})
})
