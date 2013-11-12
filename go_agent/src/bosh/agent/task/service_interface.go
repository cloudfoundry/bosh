package task

type Service interface {
	StartTask(taskFunc TaskFunc) (task Task)
}
