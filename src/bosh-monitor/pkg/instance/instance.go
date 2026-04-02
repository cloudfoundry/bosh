package instance

import "fmt"

type Instance struct {
	InstanceID string
	AgentID    string
	Job        string
	Index      string
	CID        string
	ExpectsVM  bool
	Deployment string
}

func NewInstance(data map[string]interface{}) *Instance {
	inst := &Instance{}
	if v, ok := data["id"]; ok {
		inst.InstanceID = fmt.Sprintf("%v", v)
	}
	if v, ok := data["agent_id"]; ok && v != nil {
		inst.AgentID = fmt.Sprintf("%v", v)
	}
	if v, ok := data["job"]; ok && v != nil {
		inst.Job = fmt.Sprintf("%v", v)
	}
	if v, ok := data["index"]; ok && v != nil {
		inst.Index = fmt.Sprintf("%v", v)
	}
	if v, ok := data["cid"]; ok && v != nil {
		inst.CID = fmt.Sprintf("%v", v)
	}
	if v, ok := data["expects_vm"]; ok {
		if b, ok := v.(bool); ok {
			inst.ExpectsVM = b
		}
	}
	return inst
}

func CreateInstance(data map[string]interface{}) *Instance {
	if data == nil {
		return nil
	}
	if _, ok := data["id"]; !ok {
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
		attrStr := joinStrings(attrs, ", ")
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
	attrStr := joinStrings(attrs, ", ")
	return fmt.Sprintf("%s: %s [%s]", i.Deployment, identifier, attrStr)
}

func (i *Instance) HasVM() bool {
	return i.CID != ""
}

func joinStrings(parts []string, sep string) string {
	result := ""
	for idx, p := range parts {
		if idx > 0 {
			result += sep
		}
		result += p
	}
	return result
}
