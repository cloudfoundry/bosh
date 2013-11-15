package task

import "fmt"

type asyncTaskService struct {
	currentTasks map[string]Task
}

func NewAsyncTaskService() (service asyncTaskService) {
	service.currentTasks = make(map[string]Task)
	return
}

func (service asyncTaskService) StartTask(taskFunc TaskFunc) (task Task) {
	task = Task{
		Id:       fmt.Sprintf("%d", len(service.currentTasks)+1),
		State:    TaskStateRunning,
		taskFunc: taskFunc,
	}

	service.saveTask(task)
	service.runTask(task)

	return
}

func (service asyncTaskService) FindTask(id string) (task Task, found bool) {
	task, found = service.currentTasks[id]
	return
}

func (service asyncTaskService) saveTask(task Task) {
	service.currentTasks[task.Id] = task
}

func (service asyncTaskService) runTask(task Task) {
	go func() {
		err := task.taskFunc()

		if err != nil {
			task.State = TaskStateFailed
		} else {
			task.State = TaskStateDone
		}

		service.saveTask(task)
	}()
}
