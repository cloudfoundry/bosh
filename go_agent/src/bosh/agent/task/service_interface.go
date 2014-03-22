package task

type Service interface {
	// Builds tasks but does not record them in any way
	CreateTask(TaskFunc, TaskEndFunc) (Task, error)
	CreateTaskWithId(string, TaskFunc, TaskEndFunc) Task

	// Records that task to run later
	StartTask(Task)
	FindTaskWithId(string) (Task, bool)
}
