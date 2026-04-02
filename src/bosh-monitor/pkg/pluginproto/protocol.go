package pluginproto

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
)

// Envelope types sent from server to plugin on STDIN
const (
	EnvelopeTypeInit     = "init"
	EnvelopeTypeEvent    = "event"
	EnvelopeTypeShutdown = "shutdown"
	EnvelopeTypeHTTPResponse = "http_response"
)

// Command types sent from plugin to server on STDOUT
const (
	CommandReady      = "ready"
	CommandError      = "error"
	CommandEmitAlert  = "emit_alert"
	CommandHTTPRequest = "http_request"
	CommandHTTPGet    = "http_get"
	CommandLog        = "log"
)

// Envelope is a message sent from the server to a plugin process via STDIN.
type Envelope struct {
	Type    string                 `json:"type"`
	Options map[string]interface{} `json:"options,omitempty"`
	Event   *EventData             `json:"event,omitempty"`

	// For http_response envelopes
	ID     string `json:"id,omitempty"`
	Status int    `json:"status,omitempty"`
	Body   string `json:"body,omitempty"`
}

// EventData is the serialized event sent inside an envelope.
type EventData struct {
	Kind       string                 `json:"kind"`
	ID         string                 `json:"id"`
	Severity   int                    `json:"severity,omitempty"`
	Category   string                 `json:"category,omitempty"`
	Title      string                 `json:"title,omitempty"`
	Summary    string                 `json:"summary,omitempty"`
	Source     string                 `json:"source,omitempty"`
	Deployment string                 `json:"deployment,omitempty"`
	CreatedAt  int64                  `json:"created_at,omitempty"`
	Timestamp  int64                  `json:"timestamp,omitempty"`
	AgentID    string                 `json:"agent_id,omitempty"`
	Job        string                 `json:"job,omitempty"`
	Index      string                 `json:"index,omitempty"`
	InstanceID string                 `json:"instance_id,omitempty"`
	JobState   string                 `json:"job_state,omitempty"`
	Vitals     map[string]interface{} `json:"vitals,omitempty"`
	Metrics    []MetricData           `json:"metrics,omitempty"`
	Teams      []string               `json:"teams,omitempty"`
	Attributes map[string]interface{} `json:"attributes,omitempty"`
}

// MetricData is a serialized metric inside an event.
type MetricData struct {
	Name      string            `json:"name"`
	Value     string            `json:"value"`
	Timestamp int64             `json:"timestamp"`
	Tags      map[string]string `json:"tags"`
}

// Command is a message sent from a plugin process to the server via STDOUT.
type Command struct {
	Cmd     string                 `json:"command"`
	Message string                 `json:"message,omitempty"`
	Level   string                 `json:"level,omitempty"`

	// For emit_alert
	Alert map[string]interface{} `json:"alert,omitempty"`

	// For http_request / http_get
	ID              string            `json:"id,omitempty"`
	Method          string            `json:"method,omitempty"`
	URL             string            `json:"url,omitempty"`
	Headers         map[string]string `json:"headers,omitempty"`
	Body            string            `json:"body,omitempty"`
	UseDirectorAuth bool              `json:"use_director_auth,omitempty"`
}

// WriteEnvelope writes a JSON-lines envelope to a writer.
func WriteEnvelope(w io.Writer, env *Envelope) error {
	data, err := json.Marshal(env)
	if err != nil {
		return fmt.Errorf("failed to marshal envelope: %w", err)
	}
	data = append(data, '\n')
	_, err = w.Write(data)
	return err
}

// ReadCommand reads a single JSON-lines command from a reader.
func ReadCommand(scanner *bufio.Scanner) (*Command, error) {
	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return nil, err
		}
		return nil, io.EOF
	}
	var cmd Command
	if err := json.Unmarshal(scanner.Bytes(), &cmd); err != nil {
		return nil, fmt.Errorf("failed to parse command: %w", err)
	}
	return &cmd, nil
}

// ReadEnvelope reads a single JSON-lines envelope from a reader.
func ReadEnvelope(scanner *bufio.Scanner) (*Envelope, error) {
	if !scanner.Scan() {
		if err := scanner.Err(); err != nil {
			return nil, err
		}
		return nil, io.EOF
	}
	var env Envelope
	if err := json.Unmarshal(scanner.Bytes(), &env); err != nil {
		return nil, fmt.Errorf("failed to parse envelope: %w", err)
	}
	return &env, nil
}

// WriteCommand writes a JSON-lines command to a writer.
func WriteCommand(w io.Writer, cmd *Command) error {
	data, err := json.Marshal(cmd)
	if err != nil {
		return fmt.Errorf("failed to marshal command: %w", err)
	}
	data = append(data, '\n')
	_, err = w.Write(data)
	return err
}

// NewInitEnvelope creates an init envelope with plugin options.
func NewInitEnvelope(options map[string]interface{}) *Envelope {
	return &Envelope{Type: EnvelopeTypeInit, Options: options}
}

// NewEventEnvelope creates an event envelope from event data.
func NewEventEnvelope(event *EventData) *Envelope {
	return &Envelope{Type: EnvelopeTypeEvent, Event: event}
}

// NewShutdownEnvelope creates a shutdown envelope.
func NewShutdownEnvelope() *Envelope {
	return &Envelope{Type: EnvelopeTypeShutdown}
}

// NewHTTPResponseEnvelope creates an HTTP response envelope.
func NewHTTPResponseEnvelope(id string, status int, body string) *Envelope {
	return &Envelope{
		Type:   EnvelopeTypeHTTPResponse,
		ID:     id,
		Status: status,
		Body:   body,
	}
}

// NewReadyCommand creates a ready command.
func NewReadyCommand() *Command {
	return &Command{Cmd: CommandReady}
}

// NewErrorCommand creates an error command.
func NewErrorCommand(message string) *Command {
	return &Command{Cmd: CommandError, Message: message}
}

// NewEmitAlertCommand creates an emit_alert command.
func NewEmitAlertCommand(alert map[string]interface{}) *Command {
	return &Command{Cmd: CommandEmitAlert, Alert: alert}
}

// NewLogCommand creates a log command.
func NewLogCommand(level, message string) *Command {
	return &Command{Cmd: CommandLog, Level: level, Message: message}
}

// NewHTTPRequestCommand creates an http_request command.
func NewHTTPRequestCommand(id, method, url string, headers map[string]string, body string, useDirectorAuth bool) *Command {
	return &Command{
		Cmd:             CommandHTTPRequest,
		ID:              id,
		Method:          method,
		URL:             url,
		Headers:         headers,
		Body:            body,
		UseDirectorAuth: useDirectorAuth,
	}
}

// NewHTTPGetCommand creates an http_get command.
func NewHTTPGetCommand(id, url string, useDirectorAuth bool) *Command {
	return &Command{
		Cmd:             CommandHTTPGet,
		ID:              id,
		URL:             url,
		UseDirectorAuth: useDirectorAuth,
	}
}
