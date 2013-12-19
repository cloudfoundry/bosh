package task

type TaskFunc func() (value interface{}, err error)

type TaskState string

const (
	TaskStateRunning TaskState = "running"
	TaskStateDone              = "done"
	TaskStateFailed            = "failed"
)

type Task struct {
	taskFunc TaskFunc
	Id       string
	State    TaskState
	Value    interface{}
	Error    error
}

type TaskStateValue struct {
	AgentTaskId string    `json:"agent_task_id"`
	State       TaskState `json:"state"`
}
