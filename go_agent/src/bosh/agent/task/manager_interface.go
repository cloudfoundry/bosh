package task

import (
	boshsys "bosh/system"
)

type TaskInfo struct {
	TaskID  string
	Method  string
	Payload []byte
}

type ManagerProvider interface {
	NewManager(boshsys.FileSystem, string) Manager
}

type Manager interface {
	GetTaskInfos() ([]TaskInfo, error)
	AddTaskInfo(taskInfo TaskInfo) error
	RemoveTaskInfo(taskID string) error
}
