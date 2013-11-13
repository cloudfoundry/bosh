package mbus

import "encoding/json"

type Response struct {
	AgentTaskId string `json:"agent_task_id,omitempty"`
	State       string `json:"state,omitempty"`
	Value       string `json:"value,omitempty"`
	Exception   string `json:"exception,omitempty"`
}

type taskResponse struct {
	Value     Response `json:"value"`
	Exception string   `json:"exception,omitempty"`
}

func (r Response) ToJson() (bytes []byte, err error) {
	if r.State != "" && r.AgentTaskId != "" {
		jsonValue := taskResponse{
			Value: Response{
				AgentTaskId: r.AgentTaskId,
				State:       r.State,
				Value:       r.Value,
			},
			Exception: r.Exception,
		}

		bytes, err = json.Marshal(jsonValue)
		return
	}

	bytes, err = json.Marshal(r)
	return
}
