package fakes

import boshtask "bosh/agent/task"

type FakeManager struct {
	taskIdToTaskInfo map[string]boshtask.TaskInfo

	AddTaskInfoErr error
}

func NewFakeManager() *FakeManager {
	return &FakeManager{taskIdToTaskInfo: make(map[string]boshtask.TaskInfo)}
}

func (m *FakeManager) GetTaskInfos() ([]boshtask.TaskInfo, error) {
	var taskInfos []boshtask.TaskInfo
	for _, taskInfo := range m.taskIdToTaskInfo {
		taskInfos = append(taskInfos, taskInfo)
	}
	return taskInfos, nil
}

func (m *FakeManager) AddTaskInfo(taskInfo boshtask.TaskInfo) error {
	m.taskIdToTaskInfo[taskInfo.TaskId] = taskInfo
	return m.AddTaskInfoErr
}

func (m *FakeManager) RemoveTaskInfo(taskId string) error {
	delete(m.taskIdToTaskInfo, taskId)
	return nil
}
