package instance

import (
	"fmt"
	"time"
)

type Agent struct {
	AgentID           string
	Deployment        string
	Job               string
	Index             string
	InstanceID        string
	CID               string
	DiscoveredAt      time.Time
	UpdatedAt         time.Time
	JobState          string
	NumberOfProcesses int

	agentTimeout    time.Duration
	rogueAgentAlert time.Duration
}

func NewAgent(id string, opts ...AgentOption) *Agent {
	a := &Agent{
		AgentID:         id,
		DiscoveredAt:    time.Now(),
		UpdatedAt:       time.Now(),
		agentTimeout:    60 * time.Second,
		rogueAgentAlert: 120 * time.Second,
	}
	for _, opt := range opts {
		opt(a)
	}
	return a
}

type AgentOption func(*Agent)

func WithDeployment(d string) AgentOption {
	return func(a *Agent) { a.Deployment = d }
}

func WithAgentTimeout(d time.Duration) AgentOption {
	return func(a *Agent) { a.agentTimeout = d }
}

func WithRogueAgentAlert(d time.Duration) AgentOption {
	return func(a *Agent) { a.rogueAgentAlert = d }
}

func (a *Agent) Name() string {
	if a.Deployment != "" && a.Job != "" && a.InstanceID != "" {
		name := fmt.Sprintf("%s: %s(%s) [id=%s, ", a.Deployment, a.Job, a.InstanceID, a.AgentID)
		if a.Index != "" {
			name += fmt.Sprintf("index=%s, ", a.Index)
		}
		name += fmt.Sprintf("cid=%s]", a.CID)
		return name
	}

	var parts []string
	if a.Deployment != "" {
		parts = append(parts, fmt.Sprintf("deployment=%s", a.Deployment))
	}
	if a.Job != "" {
		parts = append(parts, fmt.Sprintf("job=%s", a.Job))
	}
	if a.Index != "" {
		parts = append(parts, fmt.Sprintf("index=%s", a.Index))
	}
	if a.CID != "" {
		parts = append(parts, fmt.Sprintf("cid=%s", a.CID))
	}
	if a.InstanceID != "" {
		parts = append(parts, fmt.Sprintf("instance_id=%s", a.InstanceID))
	}

	state := ""
	for i, p := range parts {
		if i > 0 {
			state += ", "
		}
		state += p
	}
	return fmt.Sprintf("agent %s [%s]", a.AgentID, state)
}

func (a *Agent) TimedOut() bool {
	return time.Since(a.UpdatedAt) > a.agentTimeout
}

func (a *Agent) Rogue() bool {
	return time.Since(a.DiscoveredAt) > a.rogueAgentAlert && a.Deployment == ""
}

func (a *Agent) UpdateInstance(inst *Instance) {
	a.Job = inst.Job
	a.Index = inst.Index
	a.CID = inst.CID
	a.InstanceID = inst.InstanceID
}
