package nats

import (
	"encoding/json"
	"log/slog"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
)

type DirectorAlertProcessor interface {
	Process(event events.Event) error
}

// DirectorAlertSubscriber is the subset of the NATS client used by
// DirectorMonitor. Using an interface here lets tests inject a fake without
// requiring a live NATS connection.
type DirectorAlertSubscriber interface {
	SubscribeDirectorAlerts(handler func(payload string)) error
}

type DirectorMonitor struct {
	client    DirectorAlertSubscriber
	logger    *slog.Logger
	processor DirectorAlertProcessor
}

func NewDirectorMonitor(client DirectorAlertSubscriber, processor DirectorAlertProcessor, logger *slog.Logger) *DirectorMonitor {
	return &DirectorMonitor{
		client:    client,
		logger:    logger,
		processor: processor,
	}
}

func (dm *DirectorMonitor) Subscribe() error {
	return dm.client.SubscribeDirectorAlerts(dm.handleAlert)
}

func (dm *DirectorMonitor) handleAlert(payload string) {
	dm.logger.Debug("Received director alert", "payload", payload)

	var alert map[string]interface{}
	if err := json.Unmarshal([]byte(payload), &alert); err != nil {
		dm.logger.Error("Failed to parse director alert", "error", err)
		return
	}

	if !dm.validPayload(alert) {
		return
	}

	if err := dm.processor.Process(events.NewAlert(alert)); err != nil {
		dm.logger.Error("Failed to process director alert", "error", err)
	}
}

func (dm *DirectorMonitor) validPayload(payload map[string]interface{}) bool {
	requiredKeys := []string{"id", "severity", "title", "summary", "created_at"}
	for _, key := range requiredKeys {
		if _, ok := payload[key]; !ok {
			dm.logger.Error("Invalid payload from director: missing key", "key", key, "payload", payload)
			return false
		}
	}
	return true
}
