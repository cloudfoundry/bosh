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

func main() { pluginlib.Run(runGraphite) }

func runGraphite(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
	var opts graphiteOptions
	if err := json.Unmarshal(rawOpts, &opts); err != nil {
		return fmt.Errorf("invalid options: %w", err)
	}
	if opts.Host == "" || opts.Port == 0 {
		return fmt.Errorf("host and port required")
	}

	cmds <- pluginlib.LogCommand("info", "Graphite delivery agent is running...")

	addr := net.JoinHostPort(opts.Host, fmt.Sprintf("%d", opts.Port))
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
			if len(event.Metrics) == 0 {
				continue
			}

			var buf strings.Builder
			prefix := getMetricPrefix(opts, event)
			for _, metric := range event.Metrics {
				metricName := prefix + "." + strings.ReplaceAll(metric.Name, ".", "_")
				ts := metric.Timestamp
				if !epochRegex.MatchString(fmt.Sprintf("%d", ts)) {
					ts = time.Now().Unix()
				}
				fmt.Fprintf(&buf, "%s %s %d\n", metricName, metric.Value, ts)
			}

			var conn net.Conn
			var dialErr error
			maxAttempts := opts.MaxRetries
			if maxAttempts == 0 {
				maxAttempts = 1
			} else if maxAttempts < 0 {
				maxAttempts = 1<<31 - 1
			}
			for attempt := 0; attempt < maxAttempts; attempt++ {
				conn, dialErr = net.DialTimeout("tcp", addr, 5*time.Second)
				if dialErr == nil {
					break
				}
				cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Failed to connect to Graphite (attempt %d): %v", attempt+1, dialErr))
			}
			if conn == nil {
				continue
			}
			if _, err := conn.Write([]byte(buf.String())); err != nil {
				cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Failed to write to Graphite: %v", err))
			}
			_ = conn.Close()
		}
	}
}

func getMetricPrefix(opts graphiteOptions, event *pluginlib.EventData) string {
	parts := []string{event.Deployment, event.Job, event.InstanceID, event.AgentID}
	if opts.Prefix != "" {
		parts = append([]string{opts.Prefix}, parts...)
	}
	return strings.Join(parts, ".")
}
