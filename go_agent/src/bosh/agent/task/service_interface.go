package task

type Service interface {
	// Builds tasks but does not record them in any way
	CreateTask(TaskFunc, TaskCancelFunc, TaskEndFunc) (Task, error)
	CreateTaskWithID(string, TaskFunc, TaskCancelFunc, TaskEndFunc) Task

	// Records that task to run later
	StartTask(Task)
	FindTaskWithID(string) (Task, bool)
}
