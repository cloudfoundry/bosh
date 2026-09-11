package pluginhost

import (
	"bufio"
	"encoding/json"
	"io"
	"log/slog"
	"os/exec"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const (
	shutdownTimeout = 5 * time.Second

	// sendBuffer bounds how many envelopes may be queued for a single plugin.
	// A plugin that stops reading its stdin fills this and then has further
	// envelopes dropped (with a log) instead of blocking the dispatch path —
	// which runs while the instance-manager lock is held, so it must never
	// block on a slow plugin.
	sendBuffer = 1024

	// restart backoff bounds.
	restartBackoffBase = 1 * time.Second
	restartBackoffMax  = 60 * time.Second
)

type CommandHandler interface {
	HandleCommand(pluginName string, cmd *pluginproto.Command)
}

type PluginProcess struct {
	name       string
	executable string
	events     []string
	options    map[string]interface{}
	logger     *slog.Logger
	handler    CommandHandler

	mu              sync.Mutex
	cmd             *exec.Cmd
	running         bool
	stopping        bool
	sendCh          chan *pluginproto.Envelope
	exited          chan struct{}
	startedAt       time.Time
	restartAttempts int
}

func NewPluginProcess(name, executable string, events []string, options map[string]interface{}, logger *slog.Logger, handler CommandHandler) *PluginProcess {
	return &PluginProcess{
		name:       name,
		executable: executable,
		events:     events,
		options:    options,
		logger:     logger,
		handler:    handler,
	}
}

func (p *PluginProcess) Start() error {
	cmd := exec.Command(p.executable)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		_ = stdin.Close()
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		_ = stdin.Close()
		_ = stdout.Close()
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	sendCh := make(chan *pluginproto.Envelope, sendBuffer)
	exited := make(chan struct{})

	p.mu.Lock()
	p.cmd = cmd
	p.sendCh = sendCh
	p.exited = exited
	p.running = true
	p.startedAt = time.Now()
	p.mu.Unlock()

	go p.writeLoop(stdin, sendCh)
	go p.readStderr(stderr)
	go p.readStdout(stdout)
	go p.waitForExit(cmd, exited)

	// Queue the init envelope through the writer so there is a single writer
	// touching stdin.
	p.SendEnvelope(pluginproto.NewInitEnvelope(p.options))

	return nil
}

func (p *PluginProcess) Stop() {
	p.mu.Lock()
	if !p.running {
		p.mu.Unlock()
		return
	}
	p.stopping = true
	p.running = false
	sendCh := p.sendCh
	cmd := p.cmd
	exited := p.exited
	p.sendCh = nil
	p.mu.Unlock()

	// Route shutdown through the writer (so it is written after any queued
	// envelopes and never concurrently with them), then close the channel to
	// stop the writer.
	select {
	case sendCh <- pluginproto.NewShutdownEnvelope():
	default:
	}
	close(sendCh)

	// waitForExit owns the single cmd.Wait() call and closes exited; here we
	// only wait on that signal, killing the process if it overruns the timeout.
	timer := time.NewTimer(shutdownTimeout)
	defer timer.Stop()
	select {
	case <-exited:
	case <-timer.C:
		if cmd != nil && cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		<-exited
	}
}

// SendEnvelope queues an envelope for the plugin without blocking. If the
// plugin's send buffer is full (it has stopped reading stdin), the envelope is
// dropped and logged rather than blocking the caller.
func (p *PluginProcess) SendEnvelope(env *pluginproto.Envelope) {
	p.mu.Lock()
	ch := p.sendCh
	running := p.running
	p.mu.Unlock()

	if !running || ch == nil {
		return
	}

	select {
	case ch <- env:
	default:
		p.logger.Warn("Plugin send buffer full, dropping envelope", "name", p.name, "type", env.Type)
	}
}

func (p *PluginProcess) SubscribedTo(kind string) bool {
	for _, e := range p.events {
		if e == kind {
			return true
		}
	}
	return false
}

func (p *PluginProcess) writeLoop(stdin io.WriteCloser, ch chan *pluginproto.Envelope) {
	defer func() { _ = stdin.Close() }()
	for env := range ch {
		if err := pluginproto.WriteEnvelope(stdin, env); err != nil {
			// The process is likely gone; stop writing. waitForExit observes the
			// exit and handles restart. The (now orphaned) channel is replaced on
			// restart and garbage-collected.
			p.logger.Error("Failed to send envelope to plugin", "name", p.name, "error", err)
			return
		}
	}
}

func (p *PluginProcess) readStdout(reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)
	for scanner.Scan() {
		var cmd pluginproto.Command
		if err := json.Unmarshal(scanner.Bytes(), &cmd); err != nil {
			p.logger.Error("Failed to parse command from plugin", "name", p.name, "error", err)
			continue
		}
		p.handler.HandleCommand(p.name, &cmd)
	}
	if err := scanner.Err(); err != nil {
		p.logger.Error("Plugin stdout read error", "name", p.name, "error", err)
	}
}

func (p *PluginProcess) readStderr(reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		p.logger.Warn("Plugin stderr", "name", p.name, "line", scanner.Text())
	}
}

func (p *PluginProcess) waitForExit(cmd *exec.Cmd, exited chan struct{}) {
	err := cmd.Wait()
	close(exited)

	p.mu.Lock()
	stopping := p.stopping
	uptime := time.Since(p.startedAt)
	p.running = false
	// If the plugin ran for longer than restartBackoffMax it was healthy long
	// enough that the previous crash history is irrelevant. Reset the counter
	// so the next restart begins with a short delay rather than a long one.
	if uptime >= restartBackoffMax {
		p.restartAttempts = 0
	}
	p.mu.Unlock()

	if !stopping {
		p.logger.Warn("Plugin process exited unexpectedly", "name", p.name, "error", err)
		go p.restartWithBackoff()
	}
}

func (p *PluginProcess) restartWithBackoff() {
	p.mu.Lock()
	if p.stopping {
		p.mu.Unlock()
		return
	}
	p.restartAttempts++
	attempt := p.restartAttempts
	p.mu.Unlock()

	delay := backoffDelay(attempt)
	time.Sleep(delay)

	p.mu.Lock()
	stopping := p.stopping
	p.mu.Unlock()
	if stopping {
		return
	}

	p.logger.Info("Restarting plugin", "name", p.name, "attempt", attempt, "delay", delay)
	if err := p.Start(); err != nil {
		p.logger.Error("Failed to restart plugin", "name", p.name, "error", err)
		go p.restartWithBackoff()
	}
}

// backoffDelay returns an exponential backoff capped at restartBackoffMax.
func backoffDelay(attempt int) time.Duration {
	d := restartBackoffBase
	for i := 1; i < attempt; i++ {
		d *= 2
		if d >= restartBackoffMax {
			return restartBackoffMax
		}
	}
	return d
}
