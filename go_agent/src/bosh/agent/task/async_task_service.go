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

func (service asyncTaskService) CreateTask(taskFunc TaskFunc, taskEndFunc TaskEndFunc) Task {
	uuid, _ := service.uuidGen.Generate()

	return service.CreateTaskWithId(uuid, taskFunc, taskEndFunc)
}

func (service asyncTaskService) CreateTaskWithId(id string, taskFunc TaskFunc, taskEndFunc TaskEndFunc) Task {
	return Task{
		Id:          id,
		State:       TaskStateRunning,
		TaskFunc:    taskFunc,
		TaskEndFunc: taskEndFunc,
	}
}

func (service asyncTaskService) StartTask(task Task) {
	taskChan := make(chan Task)

	service.taskSem <- func() {
		service.currentTasks[task.Id] = task
		taskChan <- task
	}

	recordedTask := <-taskChan
	service.taskChan <- recordedTask
}

func (service asyncTaskService) FindTaskWithId(id string) (Task, bool) {
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
			service.logger.Error("Task Service", "Failed processing task #%s got: %s", task.Id, err.Error())
		} else {
			task.Value = value
			task.State = TaskStateDone
		}

		if task.TaskEndFunc != nil {
			task.TaskEndFunc(task)
		}

		service.taskSem <- func() {
			service.currentTasks[task.Id] = task
		}
	}
}
