package events

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"
)

// Event is the minimal contract required by the event-processing pipeline.
// Implementations (*Alert and *Heartbeat) provide additional methods
// (ToHash, ToJSON, Metrics, etc.) but callers that only need to validate,
// dispatch, or de-duplicate events depend solely on this interface.
type Event interface {
	ID() string
	Kind() string
	Validate() []string
}

func Create(kind string, attributes map[string]interface{}) (Event, error) {
	switch kind {
	case "heartbeat":
		return NewHeartbeat(attributes), nil
	case "alert":
		return NewAlert(attributes), nil
	default:
		return nil, fmt.Errorf("cannot find '%s' event handler", kind)
	}
}

func CreateAndValidate(kind string, attributes map[string]interface{}) (Event, error) {
	event, err := Create(kind, attributes)
	if err != nil {
		return nil, err
	}
	EnsureID(event)
	if errs := event.Validate(); len(errs) > 0 {
		return nil, fmt.Errorf("invalid event: %s", strings.Join(errs, ", "))
	}
	return event, nil
}

// EnsureID assigns a generated ID to an event that has none, so
// internally-created events (e.g. monitor-raised alerts) don't fail the
// "id is missing" validation.
func EnsureID(event Event) {
	if event.ID() != "" {
		return
	}
	switch e := event.(type) {
	case *Alert:
		e.AlertID = uuid.New().String()
	case *Heartbeat:
		e.HeartbeatID = uuid.New().String()
	}
}

func ParseAttributes(data interface{}) (map[string]interface{}, error) {
	switch v := data.(type) {
	case map[string]interface{}:
		return v, nil
	case string:
		var m map[string]interface{}
		if err := json.Unmarshal([]byte(v), &m); err != nil {
			return nil, fmt.Errorf("cannot parse event data: %w", err)
		}
		return m, nil
	default:
		return nil, fmt.Errorf("cannot create event from %T", data)
	}
}
