package pluginhost

import (
	"fmt"
	"log/slog"
	"sync"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

type AlertEmitter interface {
	Process(kind string, data map[string]interface{}) error
}

type DirectorRequester interface {
	PerformRequestForPlugin(method, path string, headers map[string]string, body string, useDirectorAuth bool) (string, int, error)
}

type Host struct {
	mu        sync.RWMutex
	processes map[string]*PluginProcess
	logger    *slog.Logger
	emitter   AlertEmitter
	director  DirectorRequester
}

func NewHost(logger *slog.Logger, emitter AlertEmitter, director DirectorRequester) *Host {
	return &Host{
		processes: make(map[string]*PluginProcess),
		logger:    logger,
		emitter:   emitter,
		director:  director,
	}
}

func (h *Host) SetEmitter(emitter AlertEmitter) {
	h.emitter = emitter
}

func (h *Host) StartPlugins(plugins []config.PluginConfig) error {
	for _, pluginCfg := range plugins {
		executable := pluginCfg.Executable
		if executable == "" {
			executable = fmt.Sprintf("hm-%s", pluginCfg.Name)
		}

		proc := NewPluginProcess(pluginCfg.Name, executable, pluginCfg.Events, pluginCfg.Options, h.logger, h)
		if err := proc.Start(); err != nil {
			h.logger.Error("Failed to start plugin", "name", pluginCfg.Name, "error", err)
			continue
		}

		h.mu.Lock()
		h.processes[pluginCfg.Name] = proc
		h.mu.Unlock()

		h.logger.Info("Plugin started", "name", pluginCfg.Name, "executable", executable)
	}
	return nil
}

func (h *Host) Dispatch(kind string, event events.Event) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	eventData := eventToProto(event)
	envelope := pluginproto.NewEventEnvelope(eventData)

	for _, proc := range h.processes {
		if proc.SubscribedTo(kind) {
			proc.SendEnvelope(envelope)
		}
	}
}

func (h *Host) HandleCommand(pluginName string, cmd *pluginproto.Command) {
	switch cmd.Cmd {
	case pluginproto.CommandEmitAlert:
		if h.emitter != nil && cmd.Alert != nil {
			if err := h.emitter.Process("alert", cmd.Alert); err != nil {
				h.logger.Error("Plugin emit_alert failed", "plugin", pluginName, "error", err)
			}
		}
	case pluginproto.CommandHTTPRequest:
		h.handleHTTPRequest(pluginName, cmd)
	case pluginproto.CommandHTTPGet:
		h.handleHTTPGet(pluginName, cmd)
	case pluginproto.CommandLog:
		level := cmd.Level
		if level == "" {
			level = "info"
		}
		switch level {
		case "debug":
			h.logger.Debug(fmt.Sprintf("[plugin:%s] %s", pluginName, cmd.Message))
		case "warn":
			h.logger.Warn(fmt.Sprintf("[plugin:%s] %s", pluginName, cmd.Message))
		case "error":
			h.logger.Error(fmt.Sprintf("[plugin:%s] %s", pluginName, cmd.Message))
		default:
			h.logger.Info(fmt.Sprintf("[plugin:%s] %s", pluginName, cmd.Message))
		}
	case pluginproto.CommandReady:
		h.logger.Debug("Plugin ready (late)", "plugin", pluginName)
	case pluginproto.CommandError:
		h.logger.Error("Plugin error", "plugin", pluginName, "message", cmd.Message)
	default:
		h.logger.Warn("Unknown command from plugin", "plugin", pluginName, "command", cmd.Cmd)
	}
}

func (h *Host) handleHTTPRequest(pluginName string, cmd *pluginproto.Command) {
	if h.director == nil {
		h.logger.Error("No director client for plugin HTTP request", "plugin", pluginName)
		return
	}

	go func() {
		body, status, err := h.director.PerformRequestForPlugin(cmd.Method, cmd.URL, cmd.Headers, cmd.Body, cmd.UseDirectorAuth)
		if err != nil {
			h.logger.Error("Plugin HTTP request failed", "plugin", pluginName, "error", err)
			body = err.Error()
			status = 0
		}

		resp := pluginproto.NewHTTPResponseEnvelope(cmd.ID, status, body)
		h.mu.RLock()
		proc, ok := h.processes[pluginName]
		h.mu.RUnlock()
		if ok {
			proc.SendEnvelope(resp)
		}
	}()
}

func (h *Host) handleHTTPGet(pluginName string, cmd *pluginproto.Command) {
	cmd.Method = "GET"
	h.handleHTTPRequest(pluginName, cmd)
}

func (h *Host) Shutdown() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for name, proc := range h.processes {
		h.logger.Info("Shutting down plugin", "name", name)
		proc.Stop()
	}
}

func eventToProto(event events.Event) *pluginproto.EventData {
	ed := &pluginproto.EventData{
		Kind:       event.Kind(),
		ID:         event.ID(),
		Attributes: event.Attributes(),
	}

	switch e := event.(type) {
	case *events.Alert:
		ed.Severity = e.Severity
		ed.Category = e.Category
		ed.Title = e.Title
		ed.Summary = e.Summary
		ed.Source = e.Source
		ed.Deployment = e.Deployment
		ed.CreatedAt = e.CreatedAt.Unix()
	case *events.Heartbeat:
		ed.Timestamp = e.Timestamp.Unix()
		ed.Deployment = e.Deployment
		ed.AgentID = e.AgentID
		ed.Job = e.Job
		ed.Index = e.Index
		ed.InstanceID = e.InstanceID
		ed.JobState = e.JobState
		ed.Vitals = e.Vitals
		ed.Teams = e.Teams
		for _, m := range e.HBMetrics {
			ed.Metrics = append(ed.Metrics, pluginproto.MetricData{
				Name:      m.Name,
				Value:     m.Value,
				Timestamp: m.Timestamp,
				Tags:      m.Tags,
			})
		}
	}

	return ed
}
