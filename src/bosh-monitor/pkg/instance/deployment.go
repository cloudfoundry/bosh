package instance

import (
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
)

type Deployment struct {
	DeploymentName       string
	Teams                []string
	Locked               bool
	instanceIDToInstance map[string]*Instance
	agentIDToAgent       map[string]*Agent
	instanceIDToAgent    map[string]*Agent

	agentTimeout    time.Duration
	rogueAgentAlert time.Duration
}

func NewDeployment(data director.Deployment, agentTimeout, rogueAgentAlert time.Duration) *Deployment {
	return &Deployment{
		DeploymentName:       data.Name,
		Teams:                data.Teams,
		Locked:               data.Locked,
		instanceIDToInstance: make(map[string]*Instance),
		agentIDToAgent:       make(map[string]*Agent),
		instanceIDToAgent:    make(map[string]*Agent),
		agentTimeout:         agentTimeout,
		rogueAgentAlert:      rogueAgentAlert,
	}
}

// CreateDeployment builds a Deployment from a director response, returning nil
// for an entry with no name (which the manager skips).
func CreateDeployment(data director.Deployment, agentTimeout, rogueAgentAlert time.Duration) *Deployment {
	if data.Name == "" {
		return nil
	}
	return NewDeployment(data, agentTimeout, rogueAgentAlert)
}

func (d *Deployment) Name() string {
	return d.DeploymentName
}

func (d *Deployment) AddInstance(inst *Instance) bool {
	if inst == nil {
		return false
	}
	inst.Deployment = d.DeploymentName
	d.instanceIDToInstance[inst.InstanceID] = inst
	return true
}

func (d *Deployment) RemoveInstance(instanceID string) {
	delete(d.instanceIDToAgent, instanceID)
	delete(d.instanceIDToInstance, instanceID)
}

func (d *Deployment) GetInstance(instanceID string) *Instance {
	return d.instanceIDToInstance[instanceID]
}

func (d *Deployment) Instances() []*Instance {
	result := make([]*Instance, 0, len(d.instanceIDToInstance))
	for _, inst := range d.instanceIDToInstance {
		result = append(result, inst)
	}
	return result
}

func (d *Deployment) InstanceIDs() map[string]bool {
	result := make(map[string]bool, len(d.instanceIDToInstance))
	for id := range d.instanceIDToInstance {
		result[id] = true
	}
	return result
}

func (d *Deployment) UpsertAgent(inst *Instance) bool {
	agentID := inst.AgentID
	if agentID == "" {
		if inst.ExpectsVM && !inst.HasVM() {
			agent := NewAgent("agent_with_no_vm",
				WithDeployment(d.DeploymentName),
				WithAgentTimeout(d.agentTimeout),
				WithRogueAgentAlert(d.rogueAgentAlert),
			)
			d.instanceIDToAgent[inst.InstanceID] = agent
			agent.UpdateInstance(inst)
		}
		return false
	}

	agent := d.agentIDToAgent[agentID]
	if agent == nil {
		agent = NewAgent(agentID,
			WithDeployment(d.DeploymentName),
			WithAgentTimeout(d.agentTimeout),
			WithRogueAgentAlert(d.rogueAgentAlert),
		)
		d.agentIDToAgent[agentID] = agent
		delete(d.instanceIDToAgent, inst.InstanceID)
	}
	agent.UpdateInstance(inst)
	return true
}

func (d *Deployment) RemoveAgent(agentID string) {
	delete(d.agentIDToAgent, agentID)
}

func (d *Deployment) GetAgent(agentID string) *Agent {
	return d.agentIDToAgent[agentID]
}

func (d *Deployment) Agents() []*Agent {
	result := make([]*Agent, 0, len(d.agentIDToAgent))
	for _, a := range d.agentIDToAgent {
		result = append(result, a)
	}
	return result
}

func (d *Deployment) AgentIDs() map[string]bool {
	result := make(map[string]bool, len(d.agentIDToAgent))
	for id := range d.agentIDToAgent {
		result[id] = true
	}
	return result
}

func (d *Deployment) AgentIDToAgent() map[string]*Agent {
	return d.agentIDToAgent
}

func (d *Deployment) InstanceIDToAgent() map[string]*Agent {
	return d.instanceIDToAgent
}

func (d *Deployment) UpdateTeams(teams []string) {
	d.Teams = teams
}

func (d *Deployment) IsLocked() bool {
	return d.Locked
}
