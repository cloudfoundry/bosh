package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

var ttlStatusMap = map[string]string{
	"running": "pass",
	"failing": "fail",
	"unknown": "fail",
}

type consulOptions struct {
	Host               string `json:"host"`
	Port               int    `json:"port"`
	Protocol           string `json:"protocol"`
	Namespace          string `json:"namespace"`
	Params             string `json:"params"`
	TTL                string `json:"ttl"`
	TTLNote            string `json:"ttl_note"`
	Events             bool   `json:"events"`
	HeartbeatsAsAlerts bool   `json:"heartbeats_as_alerts"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts consulOptions
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("invalid options: %w", err)
		}
		if opts.Host == "" || opts.Port == 0 || opts.Protocol == "" {
			return fmt.Errorf("host, port, and protocol required")
		}

		cmds <- pluginlib.LogCommand("info", "Consul Event Forwarder plugin is running...")

		client := &http.Client{Timeout: 10 * time.Second}
		checklist := make(map[string]bool)
		useTTL := opts.TTL != ""

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

				if forwardThisEvent(opts, event) {
					notifyConsul(client, opts, event, "event", nil, cmds)
				}

				if forwardThisTTL(useTTL, event) {
					label := labelForTTL(opts, event)
					if !checklist[label] {
						regPayload := map[string]interface{}{
							"name":  label,
							"notes": opts.TTLNote,
							"ttl":   opts.TTL,
						}
						notifyConsul(client, opts, event, "register", regPayload, cmds)
						checklist[label] = true
					} else {
						notifyConsul(client, opts, event, "ttl", nil, cmds)
					}
				}
			}
		}
	})
}

func forwardThisEvent(opts consulOptions, event *pluginlib.EventData) bool {
	if !opts.Events {
		return false
	}
	if event.Kind == "alert" {
		return true
	}
	if event.Kind == "heartbeat" && opts.HeartbeatsAsAlerts && event.InstanceID != "" {
		return true
	}
	return false
}

func forwardThisTTL(useTTL bool, event *pluginlib.EventData) bool {
	return useTTL && event.Kind == "heartbeat" && event.InstanceID != ""
}

func labelForTTL(opts consulOptions, event *pluginlib.EventData) string {
	return fmt.Sprintf("%s%s_%s", opts.Namespace, event.Job, event.InstanceID)
}

func labelForEvent(opts consulOptions, event *pluginlib.EventData) string {
	if event.Kind == "heartbeat" {
		return labelForTTL(opts, event)
	}
	if event.Kind == "alert" {
		label := strings.ToLower(strings.ReplaceAll(event.Title, " ", "_"))
		return fmt.Sprintf("%s%s", opts.Namespace, label)
	}
	return fmt.Sprintf("%sevent", opts.Namespace)
}

func notifyConsul(client *http.Client, opts consulOptions, event *pluginlib.EventData, noteType string, message interface{}, cmds chan<- *pluginlib.Command) {
	var path string
	switch noteType {
	case "event":
		path = "/v1/event/fire/" + labelForEvent(opts, event)
	case "ttl":
		jobState, _ := event.Attributes["job_state"].(string)
		status := "warn"
		if s, ok := ttlStatusMap[jobState]; ok {
			status = s
		}
		path = fmt.Sprintf("/v1/agent/check/%s/%s", status, labelForTTL(opts, event))
	case "register":
		path = "/v1/agent/check/register"
	}

	var body []byte
	if message != nil {
		body, _ = json.Marshal(message)
	} else {
		body, _ = json.Marshal(rightSizedBody(event))
	}

	url := fmt.Sprintf("%s://%s:%d%s", opts.Protocol, opts.Host, opts.Port, path)
	if opts.Params != "" {
		url += "?" + opts.Params
	}

	req, err := http.NewRequest("PUT", url, bytes.NewReader(body))
	if err != nil {
		cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Could not forward event to Consul: %v", err))
		return
	}
	req.Header.Set("Content-Type", "application/javascript")

	go func() {
		resp, err := client.Do(req)
		if err != nil {
			cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Could not forward event to Consul Cluster @%s: %v", opts.Host, err))
			return
		}
		resp.Body.Close()
	}()
}

func rightSizedBody(event *pluginlib.EventData) interface{} {
	if event.Kind == "heartbeat" {
		vitals := event.Vitals
		cpu, _ := vitals["cpu"].(map[string]interface{})
		disk, _ := vitals["disk"].(map[string]interface{})
		mem, _ := vitals["mem"].(map[string]interface{})
		swap, _ := vitals["swap"].(map[string]interface{})
		load, _ := vitals["load"].([]interface{})

		eph, _ := disk["ephemeral"].(map[string]interface{})
		sys, _ := disk["system"].(map[string]interface{})

		return map[string]interface{}{
			"agent": event.AgentID,
			"name":  fmt.Sprintf("%s/%s", event.Job, event.InstanceID),
			"id":    event.InstanceID,
			"state": event.JobState,
			"data": map[string]interface{}{
				"cpu": mapValues(cpu),
				"dsk": map[string]interface{}{
					"eph": mapValues(eph),
					"sys": mapValues(sys),
				},
				"ld":  load,
				"mem": mapValues(mem),
				"swp": mapValues(swap),
			},
		}
	}
	return map[string]interface{}{
		"kind":       event.Kind,
		"id":         event.ID,
		"severity":   event.Severity,
		"title":      event.Title,
		"summary":    event.Summary,
		"source":     event.Source,
		"deployment": event.Deployment,
		"created_at": event.CreatedAt,
	}
}

func mapValues(m map[string]interface{}) []interface{} {
	var result []interface{}
	for _, v := range m {
		result = append(result, v)
	}
	return result
}
