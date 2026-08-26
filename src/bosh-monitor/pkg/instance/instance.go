package instance

import (
	"fmt"
	"strings"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
)

type Instance struct {
	InstanceID string
	AgentID    string
	Job        string
	Index      string
	CID        string
	ExpectsVM  bool
	Deployment string
}

func NewInstance(data director.Instance) *Instance {
	return &Instance{
		InstanceID: data.ID,
		AgentID:    data.AgentID,
		Job:        data.Job,
		Index:      data.Index.String(),
		CID:        data.CID,
		ExpectsVM:  data.ExpectsVM,
	}
}

// CreateInstance builds an Instance from a director response, returning nil for
// an entry with no id (which the manager skips).
func CreateInstance(data director.Instance) *Instance {
	if data.ID == "" {
		return nil
	}
	return NewInstance(data)
}

func (i *Instance) Name() string {
	if i.Job != "" {
		identifier := fmt.Sprintf("%s(%s)", i.Job, i.InstanceID)
		var attrs []string
		if i.AgentID != "" {
			attrs = append(attrs, fmt.Sprintf("agent_id=%s", i.AgentID))
		}
		if i.Index != "" {
			attrs = append(attrs, fmt.Sprintf("index=%s", i.Index))
		}
		attrs = append(attrs, fmt.Sprintf("cid=%s", i.CID))
		attrStr := strings.Join(attrs, ", ")
		return fmt.Sprintf("%s: %s [%s]", i.Deployment, identifier, attrStr)
	}

	identifier := fmt.Sprintf("instance %s", i.InstanceID)
	var attrs []string
	if i.AgentID != "" {
		attrs = append(attrs, fmt.Sprintf("agent_id=%s", i.AgentID))
	}
	if i.Job != "" {
		attrs = append(attrs, fmt.Sprintf("job=%s", i.Job))
	}
	if i.Index != "" {
		attrs = append(attrs, fmt.Sprintf("index=%s", i.Index))
	}
	if i.CID != "" {
		attrs = append(attrs, fmt.Sprintf("cid=%s", i.CID))
	}
	if i.ExpectsVM {
		attrs = append(attrs, "expects_vm=true")
	}
	attrStr := strings.Join(attrs, ", ")
	return fmt.Sprintf("%s: %s [%s]", i.Deployment, identifier, attrStr)
}

func (i *Instance) HasVM() bool {
	return i.CID != ""
}
