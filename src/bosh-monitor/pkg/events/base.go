package events

import (
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
)

type Event interface {
	ID() string
	Kind() string
	Validate() []string
	Valid() bool
	ToHash() map[string]interface{}
	ToJSON() (string, error)
	ToPlainText() string
	ShortDescription() string
	Metrics() []Metric
	Attributes() map[string]interface{}
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
	if errs := event.Validate(); len(errs) > 0 {
		return nil, fmt.Errorf("invalid event: %s", joinErrors(errs))
	}
	if event.ID() == "" {
		switch e := event.(type) {
		case *Alert:
			e.AlertID = uuid.New().String()
		case *Heartbeat:
			e.HeartbeatID = uuid.New().String()
		}
	}
	return event, nil
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

func joinErrors(errs []string) string {
	result := ""
	for i, e := range errs {
		if i > 0 {
			result += ", "
		}
		result += e
	}
	return result
}
