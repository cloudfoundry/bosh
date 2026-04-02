package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

const apiURI = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

type pagerdutyOptions struct {
	ServiceKey string `json:"service_key"`
	HTTPProxy  string `json:"http_proxy"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts pagerdutyOptions
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("invalid options: %w", err)
		}
		if opts.ServiceKey == "" {
			return fmt.Errorf("service_key required")
		}

		cmds <- pluginlib.LogCommand("info", "Pagerduty delivery agent is running...")

		client := &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{},
			},
		}

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
				shortDesc := eventShortDescription(event)

				payload, _ := json.Marshal(map[string]interface{}{
					"service_key":  opts.ServiceKey,
					"event_type":   "trigger",
					"incident_key": event.ID,
					"description":  shortDesc,
					"details":      eventToHash(event),
				})

				go func() {
					resp, err := client.Post(apiURI, "application/json", bytes.NewReader(payload))
					if err != nil {
						cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Error sending pagerduty event: %v", err))
						return
					}
					resp.Body.Close()
				}()
			}
		}
	})
}

func eventShortDescription(e *pluginlib.EventData) string {
	switch e.Kind {
	case "alert":
		return fmt.Sprintf("Severity %d: %s %s", e.Severity, e.Source, e.Title)
	case "heartbeat":
		return fmt.Sprintf("Heartbeat from %s/%s (agent_id=%s)", e.Job, e.InstanceID, e.AgentID)
	default:
		return e.ID
	}
}

func eventToHash(e *pluginlib.EventData) map[string]interface{} {
	result := map[string]interface{}{
		"kind": e.Kind,
		"id":   e.ID,
	}
	if e.Kind == "alert" {
		result["severity"] = e.Severity
		result["title"] = e.Title
		result["summary"] = e.Summary
		result["source"] = e.Source
		result["deployment"] = e.Deployment
		result["created_at"] = e.CreatedAt
	} else {
		result["timestamp"] = e.Timestamp
		result["deployment"] = e.Deployment
		result["agent_id"] = e.AgentID
		result["job"] = e.Job
		result["instance_id"] = e.InstanceID
	}
	return result
}
