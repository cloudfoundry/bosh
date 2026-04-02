package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		cmds <- pluginlib.LogCommand("info", "Dummy delivery agent is running...")

		count := 0
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
				count++
				cmds <- pluginlib.LogCommand("info", fmt.Sprintf("Processing event! (total: %d)", count))
			}
		}
	})
}
