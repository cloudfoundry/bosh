package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"regexp"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type graphiteOptions struct {
	Host       string `json:"host"`
	Port       int    `json:"port"`
	Prefix     string `json:"prefix"`
	MaxRetries int    `json:"max_retries"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts graphiteOptions
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("invalid options: %w", err)
		}
		if opts.Host == "" || opts.Port == 0 {
			return fmt.Errorf("host and port required")
		}

		cmds <- pluginlib.LogCommand("info", "Graphite delivery agent is running...")

		addr := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
		epochRegex := regexp.MustCompile(`^1[0-9]{9}$`)

		for {
			select {
			case <-ctx.Done():
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}
				if env.Event == nil || env.Event.Kind != "heartbeat" || env.Event.InstanceID == "" {
					continue
				}

				event := env.Event
				for _, metric := range event.Metrics {
					prefix := getMetricPrefix(opts, event)
					metricName := prefix + "." + strings.ReplaceAll(metric.Name, ".", "_")

					ts := metric.Timestamp
					if !epochRegex.MatchString(fmt.Sprintf("%d", ts)) {
						ts = time.Now().Unix()
					}

					line := fmt.Sprintf("%s %s %d\n", metricName, metric.Value, ts)

					conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
					if err != nil {
						cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Failed to connect to Graphite: %v", err))
						continue
					}
					conn.Write([]byte(line))
					conn.Close()
				}
			}
		}
	})
}

func getMetricPrefix(opts graphiteOptions, event *pluginlib.EventData) string {
	parts := []string{event.Deployment, event.Job, event.InstanceID, event.AgentID}
	if opts.Prefix != "" {
		parts = append([]string{opts.Prefix}, parts...)
	}
	return strings.Join(parts, ".")
}
