package fakes

import boshtask "bosh/agent/task"

type FakeService struct {
	Tasks                map[string]boshtask.Task
	StartTaskFunc        boshtask.TaskFunc
	StartTaskStartedTask boshtask.Task
}

func (s *FakeService) StartTask(taskFunc boshtask.TaskFunc) (startedTask boshtask.Task) {
	s.StartTaskFunc = taskFunc
	startedTask = s.StartTaskStartedTask
	return
}

func (s *FakeService) FindTask(id string) (task boshtask.Task, found bool) {
	task, found = s.Tasks[id]
	return
}
