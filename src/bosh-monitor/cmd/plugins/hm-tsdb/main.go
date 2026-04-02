package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type tsdbOptions struct {
	Host       string `json:"host"`
	Port       int    `json:"port"`
	MaxRetries int    `json:"max_retries"`
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts tsdbOptions
		if err := json.Unmarshal(rawOpts, &opts); err != nil {
			return fmt.Errorf("invalid options: %w", err)
		}
		if opts.Host == "" || opts.Port == 0 {
			return fmt.Errorf("host and port required")
		}

		cmds <- pluginlib.LogCommand("info", "TSDB delivery agent is running...")

		addr := fmt.Sprintf("%s:%d", opts.Host, opts.Port)

		for {
			select {
			case <-ctx.Done():
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}
				if env.Event == nil || env.Event.Kind == "alert" {
					continue
				}

				event := env.Event
				for _, metric := range event.Metrics {
					tags := make(map[string]string)
					for k, v := range metric.Tags {
						if strings.TrimSpace(v) != "" {
							tags[k] = v
						}
					}
					tags["deployment"] = event.Deployment

					tagStr := ""
					for k, v := range tags {
						tagStr += fmt.Sprintf(" %s=%s", k, v)
					}

					line := fmt.Sprintf("put %s %d %s%s\n", metric.Name, metric.Timestamp, metric.Value, tagStr)

					conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
					if err != nil {
						cmds <- pluginlib.LogCommand("error", fmt.Sprintf("Failed to connect to TSDB: %v", err))
						continue
					}
					conn.Write([]byte(line))
					conn.Close()
				}
			}
		}
	})
}
