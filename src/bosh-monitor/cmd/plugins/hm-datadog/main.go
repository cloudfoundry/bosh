package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

// datadogSeriesURLTemplate and datadogEventsURLTemplate are vars so tests can
// override them to point at an httptest.Server.
var datadogSeriesURLTemplate = "https://api.datadoghq.com/api/v1/series?api_key=%s"
var datadogEventsURLTemplate = "https://api.datadoghq.com/api/v1/events?api_key=%s"

type datadogOptions struct {
	APIKey               string            `json:"api_key"`
	ApplicationKey       string            `json:"application_key"`
	PagerdutyServiceName string            `json:"pagerduty_service_name"`
	CustomTags           map[string]string `json:"custom_tags"`
}

func main() { pluginlib.Run(runDatadog) }

func runDatadog(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
	var opts datadogOptions
	if err := json.Unmarshal(rawOpts, &opts); err != nil {
		return fmt.Errorf("invalid options: %w", err)
	}
	if opts.APIKey == "" || opts.ApplicationKey == "" {
		return fmt.Errorf("api_key and application_key required")
	}

		cmds <- pluginlib.LogCommand("info", "DataDog plugin is running...")

		client := &http.Client{Timeout: 30 * time.Second}

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

			switch env.Event.Kind {
			case "heartbeat":
				if env.Event.InstanceID != "" {
					go processHeartbeat(ctx, client, opts, env.Event, cmds)
				}
			case "alert":
				go processAlert(ctx, client, opts, env.Event, cmds)
			}
			}
		}
}

func processHeartbeat(ctx context.Context, client *http.Client, opts datadogOptions, event *pluginlib.EventData, cmds chan<- *pluginlib.Command) {
	tags := []string{
		fmt.Sprintf("job:%s", event.Job),
		fmt.Sprintf("index:%s", event.Index),
		fmt.Sprintf("id:%s", event.InstanceID),
		fmt.Sprintf("deployment:%s", event.Deployment),
		fmt.Sprintf("agent:%s", event.AgentID),
	}
	for _, team := range event.Teams {
		tags = append(tags, fmt.Sprintf("team:%s", team))
	}
	for k, v := range opts.CustomTags {
		tags = append(tags, fmt.Sprintf("%s:%s", k, v))
	}

	var series []map[string]interface{}
	for _, metric := range event.Metrics {
		series = append(series, map[string]interface{}{
			"metric": fmt.Sprintf("bosh.healthmonitor.%s", metric.Name),
			"points": [][]interface{}{{metric.Timestamp, metric.Value}},
			"tags":   tags,
		})
	}

	payload, _ := json.Marshal(map[string]interface{}{"series": series})
	url := fmt.Sprintf(datadogSeriesURLTemplate, opts.APIKey)

	resp, err := client.Post(url, "application/json", bytes.NewReader(payload))
	if err != nil {
		select {
		case cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("Could not emit points to Datadog: %v", err)):
		case <-ctx.Done():
		}
		return
	}
	_ = resp.Body.Close()
}

func processAlert(ctx context.Context, client *http.Client, opts datadogOptions, event *pluginlib.EventData, cmds chan<- *pluginlib.Command) {
	normalPriority := map[int]bool{1: true, 2: true, 3: true}

	priority := "low"
	alertType := "warning"
	if normalPriority[event.Severity] {
		priority = "normal"
		alertType = "error"
	}

	tags := []string{
		fmt.Sprintf("source:%s", event.Source),
		fmt.Sprintf("deployment:%s", event.Deployment),
	}
	for k, v := range opts.CustomTags {
		tags = append(tags, fmt.Sprintf("%s:%s", k, v))
	}

	// When a PagerDuty service name is configured, route normal-priority
	// alerts to PagerDuty through DataDog by appending @<service_name>
	// to the event body — mirroring PagingDatadogClient behaviour.
	text := event.Summary
	if opts.PagerdutyServiceName != "" && priority == "normal" {
		text = fmt.Sprintf("%s @%s", text, opts.PagerdutyServiceName)
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"title":         event.Title,
		"text":          text,
		"date_happened": event.CreatedAt,
		"tags":          tags,
		"priority":      priority,
		"alert_type":    alertType,
	})

	url := fmt.Sprintf(datadogEventsURLTemplate, opts.APIKey)
	resp, err := client.Post(url, "application/json", bytes.NewReader(payload))
	if err != nil {
		select {
		case cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("Could not emit event to Datadog: %v", err)):
		case <-ctx.Done():
		}
		return
	}
	_ = resp.Body.Close()
}
