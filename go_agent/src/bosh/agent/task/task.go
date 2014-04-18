package task

type TaskFunc func() (value interface{}, err error)

type TaskCancelFunc func(task Task) error

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
	CancelFunc  TaskCancelFunc
	TaskEndFunc TaskEndFunc
}

func (t Task) Cancel() error {
	if t.CancelFunc != nil {
		return t.CancelFunc(t)
	}
	return nil
}

type TaskStateValue struct {
	AgentTaskID string    `json:"agent_task_id"`
	State       TaskState `json:"state"`
}
