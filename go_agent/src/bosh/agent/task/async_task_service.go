package task

import "fmt"

// Access to the currentTasks map should always be performed in the semaphore
// Use the taskSem channel for that

type asyncTaskService struct {
	currentTasks map[string]Task
	taskChan     chan Task
	taskSem      chan func()
}

func NewAsyncTaskService() (service asyncTaskService) {
	service.currentTasks = make(map[string]Task)
	service.taskChan = make(chan Task)
	service.taskSem = make(chan func())

	go service.processTasks()
	go service.processSemFuncs()
	return
}

func (service asyncTaskService) StartTask(taskFunc TaskFunc) (task Task) {
	taskChan := make(chan Task)

	service.taskSem <- func() {
		task = Task{
			Id:       fmt.Sprintf("%d", len(service.currentTasks)+1),
			State:    TaskStateRunning,
			taskFunc: taskFunc,
		}

		service.currentTasks[task.Id] = task
		taskChan <- task
	}

	task = <-taskChan
	service.taskChan <- task
	return
}

func (service asyncTaskService) FindTask(id string) (task Task, found bool) {
	taskChan := make(chan Task)
	foundChan := make(chan bool)

	service.taskSem <- func() {
		task, found := service.currentTasks[id]
		taskChan <- task
		foundChan <- found
	}

	task = <-taskChan
	found = <-foundChan
	return
}

func (service asyncTaskService) processSemFuncs() {
	for {
		do := <-service.taskSem
		do()
	}
}

func (service asyncTaskService) processTasks() {
	for {
		task := <-service.taskChan

		value, err := task.taskFunc()

		if err != nil {
			task.State = TaskStateFailed
		} else {
			task.Value = value
			task.State = TaskStateDone
		}

		service.taskSem <- func() {
			service.currentTasks[task.Id] = task
		}
	}
}
