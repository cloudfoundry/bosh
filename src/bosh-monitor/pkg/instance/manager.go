package instance

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
)

type EventProcessor interface {
	Process(event events.Event) error
}

type Director interface {
	Deployments() ([]director.Deployment, error)
	GetDeploymentInstances(name string) ([]director.Instance, error)
}

// ResurrectionChecker determines whether resurrection is enabled for a given
// deployment + instance group. A nil implementation enables resurrection for
// all instances.
type ResurrectionChecker interface {
	ResurrectionEnabled(deploymentName, instanceGroup string) bool
}

type Manager struct {
	mu sync.RWMutex

	unmanagedAgents             map[string]*Agent
	deploymentNameToDeployments map[string]*Deployment
	heartbeatsReceived          int
	alertsProcessed             int
	directorInitialSyncDone     bool

	processor       EventProcessor
	logger          *slog.Logger
	agentTimeout    time.Duration
	rogueAgentAlert time.Duration
	resurrectionMgr ResurrectionChecker
}

func NewManager(processor EventProcessor, logger *slog.Logger, agentTimeout, rogueAgentAlert time.Duration) *Manager {
	return &Manager{
		unmanagedAgents:             make(map[string]*Agent),
		deploymentNameToDeployments: make(map[string]*Deployment),
		processor:                   processor,
		logger:                      logger,
		agentTimeout:                agentTimeout,
		rogueAgentAlert:             rogueAgentAlert,
	}
}

// SetResurrectionChecker sets the resurrection config checker used to filter
// instances in deployment_health alerts. Call this after construction once the
// resurrection manager is available.
func (m *Manager) SetResurrectionChecker(rc ResurrectionChecker) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.resurrectionMgr = rc
}

// resurrectionEnabled returns true if resurrection is allowed for the given
// deployment + instance group, according to any configured resurrection config.
// Defaults to true when no checker has been configured.
func (m *Manager) resurrectionEnabled(deployment, instanceGroup string) bool {
	if m.resurrectionMgr == nil {
		return true
	}
	return m.resurrectionMgr.ResurrectionEnabled(deployment, instanceGroup)
}

func (m *Manager) HeartbeatsReceived() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.heartbeatsReceived
}

func (m *Manager) AlertsProcessed() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.alertsProcessed
}

func (m *Manager) DirectorInitialDeploymentSyncDone() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.directorInitialSyncDone
}

func (m *Manager) DeploymentsCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.deploymentNameToDeployments)
}

func (m *Manager) AgentsCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	agentIDs := make(map[string]bool)
	for id := range m.unmanagedAgents {
		agentIDs[id] = true
	}
	for _, d := range m.deploymentNameToDeployments {
		for id := range d.AgentIDs() {
			agentIDs[id] = true
		}
	}
	deletedCount := 0
	for _, d := range m.deploymentNameToDeployments {
		deletedCount += len(d.InstanceIDToAgent())
	}
	return len(agentIDs) + deletedCount
}

func (m *Manager) InstancesCount() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	count := 0
	for _, d := range m.deploymentNameToDeployments {
		count += len(d.Instances())
	}
	return count
}

func (m *Manager) FetchDeployments(d Director) error {
	deployments, err := d.Deployments()
	if err != nil {
		return err
	}

	m.SyncDeployments(deployments)

	for _, deployment := range deployments {
		name := deployment.Name
		m.logger.Info("Found deployment", "name", name)

		instancesData, err := d.GetDeploymentInstances(name)
		if err != nil {
			return err
		}
		m.SyncDeploymentState(deployment, instancesData)
	}

	m.mu.Lock()
	m.directorInitialSyncDone = true
	m.mu.Unlock()
	return nil
}

func (m *Manager) SyncDeployments(deployments []director.Deployment) {
	m.mu.Lock()
	defer m.mu.Unlock()

	activeNames := make(map[string]bool)
	for _, data := range deployments {
		d := CreateDeployment(data, m.agentTimeout, m.rogueAgentAlert)
		if d == nil {
			continue
		}
		if _, exists := m.deploymentNameToDeployments[d.Name()]; !exists {
			m.deploymentNameToDeployments[d.Name()] = d
		}
		activeNames[d.Name()] = true
	}

	for name, deployment := range m.deploymentNameToDeployments {
		if !activeNames[name] {
			m.logger.Warn("Found stale deployment, removing", "name", name)
			for id := range deployment.AgentIDs() {
				delete(m.unmanagedAgents, id)
			}
			delete(m.deploymentNameToDeployments, name)
		}
	}
}

func (m *Manager) SyncDeploymentState(deploymentData director.Deployment, instancesData []director.Instance) {
	name := deploymentData.Name

	m.mu.Lock()
	defer m.mu.Unlock()

	if deployment, ok := m.deploymentNameToDeployments[name]; ok {
		deployment.UpdateTeams(deploymentData.Teams)
		deployment.Locked = deploymentData.Locked
	}

	// Sync instances
	m.syncInstances(name, instancesData)

	// Sync agents
	deployment := m.deploymentNameToDeployments[name]
	if deployment == nil {
		return
	}
	instances := deployment.Instances()
	activeAgentIDs := make(map[string]bool)
	for _, inst := range instances {
		if deployment.UpsertAgent(inst) {
			activeAgentIDs[inst.AgentID] = true
		}
	}
	for id := range deployment.AgentIDs() {
		if !activeAgentIDs[id] {
			m.removeAgentLocked(id)
		}
	}
	for id := range activeAgentIDs {
		delete(m.unmanagedAgents, id)
	}
}

func (m *Manager) syncInstances(deploymentName string, instancesData []director.Instance) {
	deployment := m.deploymentNameToDeployments[deploymentName]
	if deployment == nil {
		return
	}

	activeIDs := make(map[string]bool)
	for _, data := range instancesData {
		inst := CreateInstance(data)
		if inst != nil && deployment.AddInstance(inst) {
			activeIDs[inst.InstanceID] = true
		}
	}

	existingIDs := deployment.InstanceIDs()
	for id := range existingIDs {
		if !activeIDs[id] {
			deployment.RemoveInstance(id)
		}
	}
}

// SyncInstancesPublic is the public version for testing.
func (m *Manager) SyncInstancesPublic(deploymentName string, instancesData []director.Instance) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.syncInstances(deploymentName, instancesData)
}

// SyncAgentsPublic is the public version for testing.
func (m *Manager) SyncAgentsPublic(deploymentName string, instances []*Instance) {
	m.mu.Lock()
	defer m.mu.Unlock()

	deployment := m.deploymentNameToDeployments[deploymentName]
	if deployment == nil {
		return
	}
	activeAgentIDs := make(map[string]bool)
	for _, inst := range instances {
		if deployment.UpsertAgent(inst) {
			activeAgentIDs[inst.AgentID] = true
		}
	}
	for id := range deployment.AgentIDs() {
		if !activeAgentIDs[id] {
			m.removeAgentLocked(id)
		}
	}
	for id := range activeAgentIDs {
		delete(m.unmanagedAgents, id)
	}
}

func (m *Manager) GetAgentsForDeployment(deploymentName string) map[string]*Agent {
	m.mu.RLock()
	defer m.mu.RUnlock()
	deployment := m.deploymentNameToDeployments[deploymentName]
	if deployment == nil {
		return map[string]*Agent{}
	}
	return deployment.AgentIDToAgent()
}

func (m *Manager) GetDeletedAgentsForDeployment(deploymentName string) map[string]*Agent {
	m.mu.RLock()
	defer m.mu.RUnlock()
	deployment := m.deploymentNameToDeployments[deploymentName]
	if deployment == nil {
		return map[string]*Agent{}
	}
	return deployment.InstanceIDToAgent()
}

func (m *Manager) GetInstancesForDeployment(deploymentName string) []*Instance {
	m.mu.RLock()
	defer m.mu.RUnlock()
	deployment := m.deploymentNameToDeployments[deploymentName]
	if deployment == nil {
		return nil
	}
	return deployment.Instances()
}

func (m *Manager) UnresponsiveAgents() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		count := 0
		for _, agent := range deployment.Agents() {
			if agent.TimedOut() {
				count++
			}
		}
		result[name] = count
	}
	return result
}

func (m *Manager) UnhealthyAgents() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		count := 0
		for _, agent := range deployment.Agents() {
			if agent.JobState == "running" && agent.NumberOfProcesses == 0 {
				count++
			}
		}
		result[name] = count
	}
	return result
}

func (m *Manager) TotalAvailableAgents() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		result[name] = len(deployment.Agents())
	}
	result["unmanaged"] = len(m.unmanagedAgents)
	return result
}

func (m *Manager) FailingInstances() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		count := 0
		for _, agent := range deployment.Agents() {
			if agent.JobState == "failing" {
				count++
			}
		}
		result[name] = count
	}
	return result
}

func (m *Manager) StoppedInstances() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		count := 0
		for _, agent := range deployment.Agents() {
			if agent.JobState == "stopped" {
				count++
			}
		}
		result[name] = count
	}
	return result
}

func (m *Manager) UnknownInstances() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make(map[string]int)
	for name, deployment := range m.deploymentNameToDeployments {
		count := 0
		for _, agent := range deployment.Agents() {
			if agent.JobState == "" {
				count++
			}
		}
		result[name] = count
	}
	return result
}

func (m *Manager) ProcessEvent(kind, subject string, payload interface{}) {
	m.mu.Lock()
	defer m.mu.Unlock()

	kindStr := kind
	parts := strings.Split(subject, ".")
	agentID := parts[len(parts)-1]

	agent := m.findManagedAgentLocked(agentID)

	if agent == nil {
		if ua, ok := m.unmanagedAgents[agentID]; ok {
			m.logger.Warn("Received event from unmanaged agent", "kind", kindStr, "agent_id", agentID)
			agent = ua
		}
	}

	if agent == nil {
		if kindStr == "shutdown" {
			return
		}
		m.logger.Warn("Received event from unmanaged agent", "kind", kindStr, "agent_id", agentID)
		agent = NewAgent(agentID,
			WithAgentTimeout(m.agentTimeout),
			WithRogueAgentAlert(m.rogueAgentAlert),
		)
		m.unmanagedAgents[agentID] = agent
	}

	var message map[string]interface{}
	switch p := payload.(type) {
	case string:
		if err := json.Unmarshal([]byte(p), &message); err != nil {
			m.logger.Error("Cannot parse incoming event", "error", err)
			return
		}
	case map[string]interface{}:
		message = p
	case nil:
		message = map[string]interface{}{}
	}

	deployment := m.deploymentNameToDeployments[agent.Deployment]

	switch kindStr {
	case "alert":
		m.onAlert(agent, message)
	case "heartbeat":
		m.onHeartbeat(agent, deployment, message)
	case "shutdown":
		m.onShutdown(agent)
	default:
		m.logger.Warn("No handler found for event", "kind", kindStr)
	}
}

func (m *Manager) onAlert(agent *Agent, message map[string]interface{}) {
	if _, ok := message["source"]; !ok {
		message["source"] = agent.Name()
		message["deployment"] = agent.Deployment
		message["job"] = agent.Job
		message["instance_id"] = agent.InstanceID
	}

	if err := m.processor.Process(events.NewAlert(message)); err != nil {
		m.logger.Error("Invalid event", "error", err)
		return
	}
	m.alertsProcessed++
}

func (m *Manager) onHeartbeat(agent *Agent, deployment *Deployment, message map[string]interface{}) {
	agent.UpdatedAt = time.Now()

	if message != nil {
		if _, ok := message["timestamp"]; !ok {
			message["timestamp"] = time.Now().Unix()
		}
		message["agent_id"] = agent.AgentID
		message["deployment"] = agent.Deployment
		message["job"] = agent.Job
		message["instance_id"] = agent.InstanceID
		var teams []string
		if deployment != nil {
			teams = deployment.Teams
		}
		message["teams"] = teams

		if js, ok := message["job_state"]; ok {
			agent.JobState = fmt.Sprintf("%v", js)
		}
		if np, ok := message["number_of_processes"]; ok {
			switch v := np.(type) {
			case float64:
				agent.NumberOfProcesses = int(v)
			case int:
				agent.NumberOfProcesses = v
			}
		}

		instID, _ := message["instance_id"].(string)
		job, _ := message["job"].(string)
		dep, _ := message["deployment"].(string)
		if instID == "" || job == "" || dep == "" {
			return
		}
	}

	if err := m.processor.Process(events.NewHeartbeat(message)); err != nil {
		m.logger.Error("Invalid event", "error", err)
		return
	}
	m.heartbeatsReceived++
}

func (m *Manager) onShutdown(agent *Agent) {
	m.logger.Info("Agent shutting down", "agent_id", agent.AgentID)
	m.removeAgentLocked(agent.AgentID)
}

func (m *Manager) AnalyzeAgents() int {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Analyzing agents...")
	started := time.Now()
	count := m.analyzeDeploymentAgents() + m.analyzeUnmanagedAgents()
	m.logger.Info("Analyzed agents", "count", count, "duration", time.Since(started))
	return count
}

func (m *Manager) analyzeDeploymentAgents() int {
	count := 0
	for _, deployment := range m.deploymentNameToDeployments {
		if deployment.IsLocked() {
			m.logger.Info("Skipping analyzing agents for locked deployment", "name", deployment.Name())
			continue
		}

		jobsToInstances := make(map[string][]string)
		for _, agent := range deployment.Agents() {
			m.analyzeAgent(agent)
			if agent.TimedOut() && !agent.Rogue() && m.resurrectionEnabled(deployment.Name(), agent.Job) {
				jobsToInstances[agent.Job] = append(jobsToInstances[agent.Job], agent.InstanceID)
			}
			count++
		}

		if len(jobsToInstances) > 0 {
			// Include the total agent count (regular + instances-with-no-VM) so the
			// resurrector plugin can compute an accurate meltdown percentage, mirroring
			// the Ruby AlertTracker#state_for which sums get_agents_for_deployment and
			// get_deleted_agents_for_deployment.
			totalAgentCount := len(deployment.Agents()) + len(deployment.InstanceIDToAgent())
			if err := m.processor.Process(events.NewAlertFromData(events.AlertData{
				Severity:          2,
				Category:          "deployment_health",
				Source:            deployment.Name(),
				Title:             fmt.Sprintf("%s has instances with timed out agents", deployment.Name()),
				CreatedAt:         time.Now(),
				Deployment:        deployment.Name(),
				JobsToInstanceIDs: jobsToInstances,
				TotalAgentCount:   totalAgentCount,
			})); err != nil {
				m.logger.Error("Failed to process deployment health alert", "error", err)
			}
		}
	}
	return count
}

func (m *Manager) analyzeUnmanagedAgents() int {
	count := 0
	for id, agent := range m.unmanagedAgents {
		m.logger.Warn("Agent is not a part of any deployment", "agent_id", id)
		m.analyzeAgent(agent)
		count++
	}
	return count
}

func (m *Manager) analyzeAgent(agent *Agent) {
	ts := time.Now().Unix()

	if agent.TimedOut() && agent.Rogue() {
		m.removeAgentLocked(agent.AgentID)
		return
	}

	if agent.TimedOut() {
		if err := m.processor.Process(events.NewAlertFromData(events.AlertData{
			Severity:   2,
			Category:   "vm_health",
			Source:     agent.Name(),
			Title:      fmt.Sprintf("%s has timed out", agent.AgentID),
			CreatedAt:  time.Unix(ts, 0),
			Deployment: agent.Deployment,
			Job:        agent.Job,
			InstanceID: agent.InstanceID,
		})); err != nil {
			m.logger.Error("Failed to process agent timeout alert", "error", err)
		}
	}

	if agent.Rogue() {
		if err := m.processor.Process(events.NewAlertFromData(events.AlertData{
			Severity:  2,
			Source:    agent.Name(),
			Title:     fmt.Sprintf("%s is not a part of any deployment", agent.AgentID),
			CreatedAt: time.Unix(ts, 0),
		})); err != nil {
			m.logger.Error("Failed to process rogue agent alert", "error", err)
		}
	}
}

func (m *Manager) AnalyzeInstances() int {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logger.Info("Analyzing instances...")
	started := time.Now()
	count := 0

	for _, deployment := range m.deploymentNameToDeployments {
		if deployment.IsLocked() {
			m.logger.Info("Skipping analyzing instances for locked deployment", "name", deployment.Name())
			continue
		}

		jobsToInstances := make(map[string][]string)
		for _, inst := range deployment.Instances() {
			if inst.ExpectsVM && !inst.HasVM() {
				if err := m.processor.Process(events.NewAlertFromData(events.AlertData{
					Severity:   2,
					Category:   "vm_health",
					Source:     inst.Name(),
					Title:      fmt.Sprintf("%s has no VM", inst.InstanceID),
					CreatedAt:  time.Now(),
					Deployment: inst.Deployment,
					Job:        inst.Job,
					InstanceID: inst.InstanceID,
				})); err != nil {
					m.logger.Error("Failed to process missing VM alert", "error", err)
				}
				if m.resurrectionEnabled(inst.Deployment, inst.Job) {
					jobsToInstances[inst.Job] = append(jobsToInstances[inst.Job], inst.InstanceID)
				}
			}
			count++
		}

		if len(jobsToInstances) > 0 {
			if err := m.processor.Process(events.NewAlertFromData(events.AlertData{
				Severity:          2,
				Category:          "deployment_health",
				Source:            deployment.Name(),
				Title:             fmt.Sprintf("%s has instances which do not have VMs", deployment.Name()),
				CreatedAt:         time.Now(),
				Deployment:        deployment.Name(),
				JobsToInstanceIDs: jobsToInstances,
			})); err != nil {
				m.logger.Error("Failed to process deployment health alert", "error", err)
			}
		}
	}

	m.logger.Info("Analyzed instances", "count", count, "duration", time.Since(started))
	return count
}

func (m *Manager) removeAgentLocked(agentID string) {
	delete(m.unmanagedAgents, agentID)
	for _, deployment := range m.deploymentNameToDeployments {
		deployment.RemoveAgent(agentID)
	}
}

func (m *Manager) findManagedAgentLocked(agentID string) *Agent {
	for _, deployment := range m.deploymentNameToDeployments {
		if agent := deployment.GetAgent(agentID); agent != nil {
			return agent
		}
	}
	return nil
}
