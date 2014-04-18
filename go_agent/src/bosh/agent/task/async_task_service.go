package task

import (
	boshlog "bosh/logger"
	boshuuid "bosh/uuid"
)

// Access to the currentTasks map should always be performed in the semaphore
// Use the taskSem channel for that

type asyncTaskService struct {
	uuidGen boshuuid.Generator
	logger  boshlog.Logger

	currentTasks map[string]Task
	taskChan     chan Task
	taskSem      chan func()
}

func NewAsyncTaskService(uuidGen boshuuid.Generator, logger boshlog.Logger) (service Service) {
	s := asyncTaskService{
		uuidGen:      uuidGen,
		logger:       logger,
		currentTasks: make(map[string]Task),
		taskChan:     make(chan Task),
		taskSem:      make(chan func()),
	}

	go s.processTasks()
	go s.processSemFuncs()

	return s
}

func (service asyncTaskService) CreateTask(
	taskFunc TaskFunc,
	taskCancelFunc TaskCancelFunc,
	taskEndFunc TaskEndFunc,
) (Task, error) {
	uuid, err := service.uuidGen.Generate()
	if err != nil {
		return Task{}, err
	}

	return service.CreateTaskWithID(uuid, taskFunc, taskCancelFunc, taskEndFunc), nil
}

func (service asyncTaskService) CreateTaskWithID(
	id string,
	taskFunc TaskFunc,
	taskCancelFunc TaskCancelFunc,
	taskEndFunc TaskEndFunc,
) Task {
	return Task{
		ID:          id,
		State:       TaskStateRunning,
		TaskFunc:    taskFunc,
		CancelFunc:  taskCancelFunc,
		TaskEndFunc: taskEndFunc,
	}
}

func (service asyncTaskService) StartTask(task Task) {
	taskChan := make(chan Task)

	service.taskSem <- func() {
		service.currentTasks[task.ID] = task
		taskChan <- task
	}

	recordedTask := <-taskChan
	service.taskChan <- recordedTask
}

func (service asyncTaskService) FindTaskWithID(id string) (Task, bool) {
	taskChan := make(chan Task)
	foundChan := make(chan bool)

	service.taskSem <- func() {
		task, found := service.currentTasks[id]
		taskChan <- task
		foundChan <- found
	}

	return <-taskChan, <-foundChan
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

		value, err := task.TaskFunc()
		if err != nil {
			task.Error = err
			task.State = TaskStateFailed
			service.logger.Error("Task Service", "Failed processing task #%s got: %s", task.ID, err.Error())
		} else {
			task.Value = value
			task.State = TaskStateDone
		}

		if task.TaskEndFunc != nil {
			task.TaskEndFunc(task)
		}

		service.taskSem <- func() {
			service.currentTasks[task.ID] = task
		}
	}
}
