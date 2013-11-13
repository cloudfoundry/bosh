package task

type Service interface {
	StartTask(taskFunc TaskFunc) (task Task)
	FindTask(id string) (task Task, found bool)
}
