package mbus

type Response struct {
	State       string `json:"state,omitempty"`
	Value       string `json:"value,omitempty"`
	AgentTaskId string `json:"agent_task_id,omitempty"`
}
