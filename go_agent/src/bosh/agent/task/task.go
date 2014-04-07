package task

type TaskFunc func() (value interface{}, err error)

type TaskEndFunc func(task Task)

type TaskState string

const (
	TaskStateRunning TaskState = "running"
	TaskStateDone    TaskState = "done"
	TaskStateFailed  TaskState = "failed"
)

type Task struct {
	ID    string
	State TaskState
	Value interface{}
	Error error

	TaskFunc    TaskFunc
	TaskEndFunc TaskEndFunc
}

type TaskStateValue struct {
	AgentTaskID string    `json:"agent_task_id"`
	State       TaskState `json:"state"`
}
