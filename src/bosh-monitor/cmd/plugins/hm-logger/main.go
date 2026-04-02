package main

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type options struct {
	Format string `json:"format"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts options
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("failed to parse options: %w", err)
		}

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
					cmds <- pluginlib.LogCommand("info", fmt.Sprintf("[%s] %s", kindUpper(env.Event.Kind), eventSummary(env.Event)))
				}
			}
		}
	})
}

func kindUpper(kind string) string {
	result := make([]byte, len(kind))
	for i := range kind {
		c := kind[i]
		if c >= 'a' && c <= 'z' {
			c -= 32
		}
		result[i] = c
	}
	return string(result)
}

func eventSummary(e *pluginlib.EventData) string {
	switch e.Kind {
	case "alert":
		createdAt := time.Unix(e.CreatedAt, 0).UTC()
		return fmt.Sprintf("Alert @ %s, severity %d: %s", createdAt.Format("2006-01-02 15:04:05 UTC"), e.Severity, e.Summary)
	case "heartbeat":
		ts := time.Unix(e.Timestamp, 0).UTC()
		desc := fmt.Sprintf("Heartbeat from %s/%s (agent_id=%s", e.Job, e.InstanceID, e.AgentID)
		if e.Index != "" {
			desc += fmt.Sprintf(" index=%s", e.Index)
		}
		desc += fmt.Sprintf(") @ %s", ts.Format("2006-01-02 15:04:05 UTC"))
		return desc
	default:
		return e.ID
	}
}
