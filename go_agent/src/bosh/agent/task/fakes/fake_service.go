package fakes

import (
	boshtask "bosh/agent/task"
)

type FakeService struct {
	StartedTasks        map[string]boshtask.Task
	CreateTaskErr       error
	CreateTaskWithIdErr error
}

func NewFakeService() *FakeService {
	return &FakeService{
		StartedTasks: make(map[string]boshtask.Task),
	}
}

func (s *FakeService) CreateTask(
	taskFunc boshtask.TaskFunc,
	taskEndFunc boshtask.TaskEndFunc,
) (boshtask.Task, error) {
	if s.CreateTaskErr != nil {
		return boshtask.Task{}, s.CreateTaskErr
	}
	return s.CreateTaskWithId("fake-generated-task-id", taskFunc, taskEndFunc), nil
}

func (s *FakeService) CreateTaskWithId(
	id string,
	taskFunc boshtask.TaskFunc,
	taskEndFunc boshtask.TaskEndFunc,
) boshtask.Task {
	return boshtask.Task{
		Id:          id,
		State:       boshtask.TaskStateRunning,
		TaskFunc:    taskFunc,
		TaskEndFunc: taskEndFunc,
	}
}

func (s *FakeService) StartTask(task boshtask.Task) {
	s.StartedTasks[task.Id] = task
}

func (s *FakeService) FindTaskWithId(id string) (boshtask.Task, bool) {
	task, found := s.StartedTasks[id]
	return task, found
}
