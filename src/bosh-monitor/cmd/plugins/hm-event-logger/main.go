package main

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		cmds <- pluginlib.LogCommand("info", "Event logger is running...")

		for {
			select {
			case <-ctx.Done():
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}
				if env.Event == nil || env.Event.Kind != "alert" {
					continue
				}

				event := env.Event
				deployment := event.Deployment
				job := event.Job
				id := event.InstanceID

				var instance *string
				if job != "" && id != "" {
					s := fmt.Sprintf("%s/%s", job, id)
					instance = &s
				}

				ts := event.CreatedAt
				if ts == 0 {
					ts = time.Now().Unix()
				}

				payload := map[string]interface{}{
					"timestamp":   fmt.Sprintf("%d", ts),
					"action":      "create",
					"object_type": "alert",
					"object_name": event.ID,
					"deployment":  deployment,
					"context": map[string]interface{}{
						"message": fmt.Sprintf("%s. Severity %d: %s %s", event.Title, event.Severity, event.Source, event.Title),
					},
				}
				if instance != nil {
					payload["instance"] = *instance
				}

				body, _ := json.Marshal(payload)
				reqID := fmt.Sprintf("event-%s-%d", event.ID, time.Now().UnixNano())

				cmds <- pluginlib.LogCommand("info", fmt.Sprintf("(Event logger) notifying director about event: %s", event.ID))
				cmds <- pluginlib.HTTPRequestCommand(reqID, "POST", "/events",
					map[string]string{"Content-Type": "application/json"},
					string(body))
			}
		}
	})
}
