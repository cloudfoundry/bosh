package instance

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

type EventProcessor interface {
	Process(kind string, data map[string]interface{}) error
}

type Director interface {
	Deployments() ([]map[string]interface{}, error)
	GetDeploymentInstances(name string) ([]map[string]interface{}, error)
}

type Manager struct {
	mu sync.RWMutex

	unmanagedAgents              map[string]*Agent
	deploymentNameToDeployments  map[string]*Deployment
	heartbeatsReceived           int
	alertsReceived               int
	alertsProcessed              int
	directorInitialSyncDone      bool

	processor       EventProcessor
	logger          *slog.Logger
	agentTimeout    time.Duration
	rogueAgentAlert time.Duration
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

func (m *Manager) FetchDeployments(director Director) error {
	deployments, err := director.Deployments()
	if err != nil {
		return err
	}

	m.SyncDeployments(deployments)

	for _, deployment := range deployments {
		name := fmt.Sprintf("%v", deployment["name"])
		m.logger.Info("Found deployment", "name", name)

		instancesData, err := director.GetDeploymentInstances(name)
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

func (m *Manager) SyncDeployments(deployments []map[string]interface{}) {
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

func (m *Manager) SyncDeploymentState(deploymentData map[string]interface{}, instancesData []map[string]interface{}) {
	name := fmt.Sprintf("%v", deploymentData["name"])

	m.mu.Lock()
	defer m.mu.Unlock()

	// Sync teams
	if deployment, ok := m.deploymentNameToDeployments[name]; ok {
		if teams, ok := deploymentData["teams"]; ok {
			if teamSlice, ok := teams.([]interface{}); ok {
				strs := make([]string, len(teamSlice))
				for i, t := range teamSlice {
					strs[i] = fmt.Sprintf("%v", t)
				}
				deployment.UpdateTeams(strs)
			} else if teamSlice, ok := teams.([]string); ok {
				deployment.UpdateTeams(teamSlice)
			}
		}
	}

	// Sync locked
	if deployment, ok := m.deploymentNameToDeployments[name]; ok {
		if locked, ok := deploymentData["locked"]; ok {
			if b, ok := locked.(bool); ok {
				deployment.Locked = b
			}
		}
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

func (m *Manager) syncInstances(deploymentName string, instancesData []map[string]interface{}) {
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
func (m *Manager) SyncInstancesPublic(deploymentName string, instancesData []map[string]interface{}) {
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
	parts := splitSubject(subject)
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

	if err := m.processor.Process("alert", message); err != nil {
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

	if err := m.processor.Process("heartbeat", message); err != nil {
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
			if agent.TimedOut() && !agent.Rogue() {
				jobsToInstances[agent.Job] = append(jobsToInstances[agent.Job], agent.InstanceID)
			}
			count++
		}

		if len(jobsToInstances) > 0 {
			m.processor.Process("alert", map[string]interface{}{
				"severity":             2,
				"category":             "deployment_health",
				"source":               deployment.Name(),
				"title":                fmt.Sprintf("%s has instances with timed out agents", deployment.Name()),
				"created_at":           time.Now().Unix(),
				"deployment":           deployment.Name(),
				"jobs_to_instance_ids": jobsToInstances,
			})
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
		m.processor.Process("alert", map[string]interface{}{
			"severity":    2,
			"category":    "vm_health",
			"source":      agent.Name(),
			"title":       fmt.Sprintf("%s has timed out", agent.AgentID),
			"created_at":  ts,
			"deployment":  agent.Deployment,
			"job":         agent.Job,
			"instance_id": agent.InstanceID,
		})
	}

	if agent.Rogue() {
		m.processor.Process("alert", map[string]interface{}{
			"severity":   2,
			"source":     agent.Name(),
			"title":      fmt.Sprintf("%s is not a part of any deployment", agent.AgentID),
			"created_at": ts,
		})
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
				m.processor.Process("alert", map[string]interface{}{
					"severity":    2,
					"category":    "vm_health",
					"source":      inst.Name(),
					"title":       fmt.Sprintf("%s has no VM", inst.InstanceID),
					"created_at":  time.Now().Unix(),
					"deployment":  inst.Deployment,
					"job":         inst.Job,
					"instance_id": inst.InstanceID,
				})
				jobsToInstances[inst.Job] = append(jobsToInstances[inst.Job], inst.InstanceID)
			}
			count++
		}

		if len(jobsToInstances) > 0 {
			m.processor.Process("alert", map[string]interface{}{
				"severity":             2,
				"category":             "deployment_health",
				"source":               deployment.Name(),
				"title":                fmt.Sprintf("%s has instances which do not have VMs", deployment.Name()),
				"created_at":           time.Now().Unix(),
				"deployment":           deployment.Name(),
				"jobs_to_instance_ids": jobsToInstances,
			})
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

func splitSubject(subject string) []string {
	var parts []string
	current := ""
	for _, c := range subject {
		if c == '.' {
			parts = append(parts, current)
			current = ""
		} else {
			current += string(c)
		}
	}
	parts = append(parts, current)
	return parts
}
