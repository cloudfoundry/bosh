package task

import (
	boshlog "bosh/logger"
	"fmt"
)

// Access to the currentTasks map should always be performed in the semaphore
// Use the taskSem channel for that

type asyncTaskService struct {
	logger       boshlog.Logger
	currentTasks map[string]Task
	taskChan     chan Task
	taskSem      chan func()
}

func NewAsyncTaskService(logger boshlog.Logger) (service Service) {
	s := asyncTaskService{
		logger:       logger,
		currentTasks: make(map[string]Task),
		taskChan:     make(chan Task),
		taskSem:      make(chan func()),
	}

	go s.processTasks()
	go s.processSemFuncs()

	return s
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
	defer service.logger.HandlePanic("Task Service Process Sem Funcs")

	for {
		do := <-service.taskSem
		do()
	}
}

func (service asyncTaskService) processTasks() {
	defer service.logger.HandlePanic("Task Service Process Tasks")

	for {
		task := <-service.taskChan

		value, err := task.taskFunc()

		if err != nil {
			task.Error = err.Error()
			task.State = TaskStateFailed

			service.logger.Error("Task Service", "Failed processing task #%s got: %s", task.Id, err.Error())
		} else {
			task.Value = value
			task.State = TaskStateDone
		}

		service.taskSem <- func() {
			service.currentTasks[task.Id] = task
		}
	}
}
