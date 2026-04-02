package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
)

type jsonOptions struct {
	Glob          string `json:"glob"`
	CheckInterval int    `json:"check_interval"`
	RestartWait   int    `json:"restart_wait"`
}

type managedProcess struct {
	cmd   *exec.Cmd
	stdin io.WriteCloser
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts jsonOptions
		json.Unmarshal(rawOpts, &opts)

		if opts.Glob == "" {
			opts.Glob = "/var/vcap/jobs/*/bin/bosh-monitor/*"
		}
		if opts.CheckInterval == 0 {
			opts.CheckInterval = 60
		}
		if opts.RestartWait == 0 {
			opts.RestartWait = 1
		}

		var mu sync.Mutex
		processes := make(map[string]*managedProcess)

		var startProcess func(bin string)
		startProcess = func(bin string) {
			cmd := exec.Command(bin)
			stdin, err := cmd.StdinPipe()
			if err != nil {
				cmds <- pluginlib.LogCommand("error", fmt.Sprintf("JSON Plugin: Failed to get stdin for %s: %v", bin, err))
				return
			}
			stderr, _ := cmd.StderrPipe()

			if err := cmd.Start(); err != nil {
				cmds <- pluginlib.LogCommand("error", fmt.Sprintf("JSON Plugin: Failed to start %s: %v", bin, err))
				return
			}

			proc := &managedProcess{cmd: cmd, stdin: stdin}
			mu.Lock()
			processes[bin] = proc
			mu.Unlock()

			cmds <- pluginlib.LogCommand("info", fmt.Sprintf("JSON Plugin: Started process %s", bin))

			if stderr != nil {
				go func() {
					scanner := bufio.NewScanner(stderr)
					for scanner.Scan() {
						cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("JSON Plugin [%s stderr]: %s", bin, scanner.Text()))
					}
				}()
			}

			go func() {
				cmd.Wait()
				mu.Lock()
				delete(processes, bin)
				mu.Unlock()
				cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("JSON Plugin: Process %s exited, restarting...", bin))
				time.Sleep(time.Duration(opts.RestartWait) * time.Second)
				startProcess(bin)
			}()
		}

		discoverAndStart := func() {
			matches, _ := filepath.Glob(opts.Glob)
			mu.Lock()
			for _, bin := range matches {
				if _, exists := processes[bin]; !exists {
					go startProcess(bin)
				}
			}
			mu.Unlock()
		}

		discoverAndStart()
		go func() {
			ticker := time.NewTicker(time.Duration(opts.CheckInterval) * time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					discoverAndStart()
				}
			}
		}()

		for {
			select {
			case <-ctx.Done():
				mu.Lock()
				for _, proc := range processes {
					proc.stdin.Close()
					proc.cmd.Process.Kill()
				}
				mu.Unlock()
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}
				if env.Event == nil {
					continue
				}
				data, _ := json.Marshal(env.Event)
				data = append(data, '\n')

				mu.Lock()
				for _, proc := range processes {
					proc.stdin.Write(data)
				}
				mu.Unlock()
			}
		}
	})
}
