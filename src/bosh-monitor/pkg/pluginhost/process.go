package pluginhost

import (
	"bufio"
	"io"
	"log/slog"
	"os/exec"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const (
	initTimeout     = 10 * time.Second
	shutdownTimeout = 5 * time.Second
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

	mu      sync.Mutex
	cmd     *exec.Cmd
	stdin   io.WriteCloser
	running bool
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
	p.mu.Lock()
	defer p.mu.Unlock()

	cmd := exec.Command(p.executable)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		stdin.Close()
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		stdin.Close()
		stdout.Close()
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	p.cmd = cmd
	p.stdin = stdin
	p.running = true

	go p.readStderr(stderr)
	go p.readStdout(stdout)

	initEnv := pluginproto.NewInitEnvelope(p.options)
	if err := pluginproto.WriteEnvelope(stdin, initEnv); err != nil {
		p.logger.Error("Failed to send init to plugin", "name", p.name, "error", err)
	}

	go p.waitForExit()

	return nil
}

func (p *PluginProcess) Stop() {
	p.mu.Lock()
	defer p.mu.Unlock()

	if !p.running {
		return
	}

	shutdownEnv := pluginproto.NewShutdownEnvelope()
	pluginproto.WriteEnvelope(p.stdin, shutdownEnv)

	done := make(chan struct{})
	go func() {
		if p.cmd != nil && p.cmd.Process != nil {
			p.cmd.Wait()
		}
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(shutdownTimeout):
		if p.cmd != nil && p.cmd.Process != nil {
			p.cmd.Process.Kill()
		}
	}

	p.running = false
}

func (p *PluginProcess) SendEnvelope(env *pluginproto.Envelope) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if !p.running || p.stdin == nil {
		return
	}

	if err := pluginproto.WriteEnvelope(p.stdin, env); err != nil {
		p.logger.Error("Failed to send envelope to plugin", "name", p.name, "error", err)
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

func (p *PluginProcess) readStdout(reader io.Reader) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)
	for scanner.Scan() {
		cmd, err := pluginproto.ReadCommand(bufio.NewScanner(
			newSingleLineReader(scanner.Bytes()),
		))
		if err != nil {
			p.logger.Error("Failed to parse command from plugin", "name", p.name, "error", err)
			continue
		}
		p.handler.HandleCommand(p.name, cmd)
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

func (p *PluginProcess) waitForExit() {
	if p.cmd == nil {
		return
	}
	err := p.cmd.Wait()

	p.mu.Lock()
	wasRunning := p.running
	p.running = false
	p.mu.Unlock()

	if wasRunning {
		p.logger.Warn("Plugin process exited unexpectedly", "name", p.name, "error", err)
		go p.restartWithBackoff()
	}
}

func (p *PluginProcess) restartWithBackoff() {
	time.Sleep(1 * time.Second)
	p.logger.Info("Restarting plugin", "name", p.name)
	if err := p.Start(); err != nil {
		p.logger.Error("Failed to restart plugin", "name", p.name, "error", err)
	}
}

type singleLineReader struct {
	data []byte
	read bool
}

func newSingleLineReader(data []byte) *singleLineReader {
	return &singleLineReader{data: data}
}

func (r *singleLineReader) Read(p []byte) (int, error) {
	if r.read {
		return 0, io.EOF
	}
	n := copy(p, r.data)
	if n < len(r.data) {
		r.data = r.data[n:]
		return n, nil
	}
	r.read = true
	return n, io.EOF
}
