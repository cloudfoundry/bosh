package testhelpers

import boshtask "bosh/agent/task"

type FakeService struct {
	StartTaskFunc        boshtask.TaskFunc
	StartTaskStartedTask boshtask.Task
}

func (s *FakeService) StartTask(taskFunc boshtask.TaskFunc) (startedTask boshtask.Task) {
	s.StartTaskFunc = taskFunc
	startedTask = s.StartTaskStartedTask
	return
}
