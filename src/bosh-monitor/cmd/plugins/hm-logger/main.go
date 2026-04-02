package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type options struct {
	Format string `json:"format"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts options
		json.Unmarshal(rawOpts, &opts)

		cmds <- pluginlib.LogCommand("info", "Logging delivery agent is running...")

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
				if opts.Format == "json" {
					data, _ := json.Marshal(env.Event)
					cmds <- pluginlib.LogCommand("info", string(data))
				} else {
					cmds <- pluginlib.LogCommand("info", fmt.Sprintf("[%s] %s", env.Event.Kind, eventSummary(env.Event)))
				}
			}
		}
	})
}

func eventSummary(e *pluginlib.EventData) string {
	switch e.Kind {
	case "alert":
		return fmt.Sprintf("Severity %d: %s %s", e.Severity, e.Source, e.Title)
	case "heartbeat":
		return fmt.Sprintf("Heartbeat from %s/%s (agent_id=%s)", e.Job, e.InstanceID, e.AgentID)
	default:
		return e.ID
	}
}
