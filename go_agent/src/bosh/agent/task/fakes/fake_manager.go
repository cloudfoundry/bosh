package fakes

import boshtask "bosh/agent/task"

type FakeManager struct {
	taskIDToTaskInfo map[string]boshtask.TaskInfo

	AddTaskInfoErr error
}

func NewFakeManager() *FakeManager {
	return &FakeManager{taskIDToTaskInfo: make(map[string]boshtask.TaskInfo)}
}

func (m *FakeManager) GetTaskInfos() ([]boshtask.TaskInfo, error) {
	var taskInfos []boshtask.TaskInfo
	for _, taskInfo := range m.taskIDToTaskInfo {
		taskInfos = append(taskInfos, taskInfo)
	}
	return taskInfos, nil
}

func (m *FakeManager) AddTaskInfo(taskInfo boshtask.TaskInfo) error {
	m.taskIDToTaskInfo[taskInfo.TaskID] = taskInfo
	return m.AddTaskInfoErr
}

func (m *FakeManager) RemoveTaskInfo(taskID string) error {
	delete(m.taskIDToTaskInfo, taskID)
	return nil
}
