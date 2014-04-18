package fakes

import (
	boshtask "bosh/agent/task"
)

type FakeService struct {
	StartedTasks        map[string]boshtask.Task
	CreateTaskErr       error
	CreateTaskWithIDErr error
}

func NewFakeService() *FakeService {
	return &FakeService{
		StartedTasks: make(map[string]boshtask.Task),
	}
}

func (s *FakeService) CreateTask(
	taskFunc boshtask.TaskFunc,
	taskCancelFunc boshtask.TaskCancelFunc,
	taskEndFunc boshtask.TaskEndFunc,
) (boshtask.Task, error) {
	if s.CreateTaskErr != nil {
		return boshtask.Task{}, s.CreateTaskErr
	}
	return s.CreateTaskWithID("fake-generated-task-id", taskFunc, taskCancelFunc, taskEndFunc), nil
}

func (s *FakeService) CreateTaskWithID(
	id string,
	taskFunc boshtask.TaskFunc,
	taskCancelFunc boshtask.TaskCancelFunc,
	taskEndFunc boshtask.TaskEndFunc,
) boshtask.Task {
	return boshtask.Task{
		ID:          id,
		State:       boshtask.TaskStateRunning,
		TaskFunc:    taskFunc,
		CancelFunc:  taskCancelFunc,
		TaskEndFunc: taskEndFunc,
	}
}

func (s *FakeService) StartTask(task boshtask.Task) {
	s.StartedTasks[task.ID] = task
}

func (s *FakeService) FindTaskWithID(id string) (boshtask.Task, bool) {
	task, found := s.StartedTasks[id]
	return task, found
}
