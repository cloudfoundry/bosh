package task

type Service interface {
	// Builds tasks but does not record them in any way
	CreateTask(TaskFunc, TaskEndFunc) (Task, error)
	CreateTaskWithID(string, TaskFunc, TaskEndFunc) Task

	// Records that task to run later
	StartTask(Task)
	FindTaskWithID(string) (Task, bool)
}
