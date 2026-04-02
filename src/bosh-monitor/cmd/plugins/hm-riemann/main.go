package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type riemannOptions struct {
	Host string `json:"host"`
	Port int    `json:"port"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts riemannOptions
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("invalid options: %w", err)
		}
		if opts.Host == "" || opts.Port == 0 {
			return fmt.Errorf("host and port required")
		}

		cmds <- pluginlib.LogCommand("info", "Riemann delivery agent is running...")

		addr := fmt.Sprintf("%s:%d", opts.Host, opts.Port)

		for {
			select {
			case <-ctx.Done():
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}
				if env.Event == nil {
					continue
				}

				event := env.Event
				switch event.Kind {
				case "heartbeat":
					if event.InstanceID != "" {
						processHeartbeat(addr, event, cmds)
					}
				case "alert":
					processAlert(addr, event, cmds)
				}
			}
		}
	})
}

func processHeartbeat(addr string, event *pluginlib.EventData, cmds chan<- *pluginlib.Command) {
	for _, metric := range event.Metrics {
		payload := map[string]interface{}{
			"service":     "bosh.hm",
			"kind":        event.Kind,
			"id":          event.ID,
			"timestamp":   event.Timestamp,
			"deployment":  event.Deployment,
			"agent_id":    event.AgentID,
			"job":         event.Job,
			"index":       event.Index,
			"instance_id": event.InstanceID,
			"job_state":   event.JobState,
			"name":        metric.Name,
			"metric":      metric.Value,
		}
		sendToRiemann(addr, payload, cmds)
	}
}

func processAlert(addr string, event *pluginlib.EventData, cmds chan<- *pluginlib.Command) {
	payload := map[string]interface{}{
		"service":    "bosh.hm",
		"kind":       event.Kind,
		"id":         event.ID,
		"severity":   event.Severity,
		"title":      event.Title,
		"summary":    event.Summary,
		"source":     event.Source,
		"deployment": event.Deployment,
		"created_at": event.CreatedAt,
		"state":      fmt.Sprintf("%d", event.Severity),
	}
	sendToRiemann(addr, payload, cmds)
}

func sendToRiemann(addr string, payload map[string]interface{}, cmds chan<- *pluginlib.Command) {
	data, _ := json.Marshal(payload)
	data = append(data, '\n')

	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Error sending riemann event: %v", err))
		return
	}
	defer conn.Close()
	conn.Write(data)
}
