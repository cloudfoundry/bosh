package director

import (
	"bytes"
	"encoding/json"
)

// Deployment is a deployment as returned by GET /deployments.
type Deployment struct {
	Name   string   `json:"name"`
	Teams  []string `json:"teams"`
	Locked bool     `json:"locked"`
}

// Instance is an instance as returned by GET /deployments/:name/instances.
type Instance struct {
	ID        string  `json:"id"`
	AgentID   string  `json:"agent_id"`
	Job       string  `json:"job"`
	Index     FlexStr `json:"index"`
	CID       string  `json:"cid"`
	ExpectsVM bool    `json:"expects_vm"`
}

// ResurrectionConfig is a config document as returned by
// GET /configs?type=resurrection.
type ResurrectionConfig struct {
	Content string `json:"content"`
}

// FlexStr is a string that tolerates a JSON value arriving as either a string
// or a number (the director's instance `index` is an integer, but historically
// the code coerced it to a string). It preserves the previous fmt.Sprintf("%v")
// behaviour: a number decodes to its literal text, an absent/null value to "".
type FlexStr string

func (f *FlexStr) UnmarshalJSON(b []byte) error {
	if len(b) == 0 || bytes.Equal(b, []byte("null")) {
		*f = ""
		return nil
	}
	if b[0] == '"' {
		var s string
		if err := json.Unmarshal(b, &s); err != nil {
			return err
		}
		*f = FlexStr(s)
		return nil
	}
	// A JSON number: keep its literal representation (e.g. 2 -> "2").
	*f = FlexStr(string(bytes.TrimSpace(b)))
	return nil
}

func (f FlexStr) String() string { return string(f) }
