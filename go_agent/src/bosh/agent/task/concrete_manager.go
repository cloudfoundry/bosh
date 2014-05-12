package task

import (
	"encoding/json"
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

type concreteManagerProvider struct{}

func NewManagerProvider() concreteManagerProvider {
	return concreteManagerProvider{}
}

func (provider concreteManagerProvider) NewManager(
	logger boshlog.Logger,
	fs boshsys.FileSystem,
	dir string,
) Manager {
	return NewManager(logger, fs, filepath.Join(dir, "tasks.json"))
}

type concreteManager struct {
	logger boshlog.Logger

	fs        boshsys.FileSystem
	fsSem     chan func()
	tasksPath string

	// Access to taskInfos must be synchronized via fsSem
	taskInfos map[string]TaskInfo
}

func NewManager(logger boshlog.Logger, fs boshsys.FileSystem, tasksPath string) Manager {
	m := &concreteManager{
		logger:    logger,
		fs:        fs,
		fsSem:     make(chan func()),
		tasksPath: tasksPath,
		taskInfos: make(map[string]TaskInfo),
	}

	go m.processFsFuncs()

	return m
}

func (m *concreteManager) GetTaskInfos() ([]TaskInfo, error) {
	taskInfosChan := make(chan map[string]TaskInfo)
	errCh := make(chan error)

	m.fsSem <- func() {
		taskInfos, err := m.readTaskInfos()
		m.taskInfos = taskInfos
		taskInfosChan <- taskInfos
		errCh <- err
	}

	taskInfos := <-taskInfosChan
	err := <-errCh

	if err != nil {
		return nil, err
	}

	var r []TaskInfo
	for _, taskInfo := range taskInfos {
		r = append(r, taskInfo)
	}

	return r, nil
}

func (m *concreteManager) AddTaskInfo(taskInfo TaskInfo) error {
	errCh := make(chan error)

	m.fsSem <- func() {
		m.taskInfos[taskInfo.TaskID] = taskInfo
		err := m.writeTaskInfos(m.taskInfos)
		errCh <- err
	}
	return <-errCh
}

func (m *concreteManager) RemoveTaskInfo(taskID string) error {
	errCh := make(chan error)

	m.fsSem <- func() {
		delete(m.taskInfos, taskID)
		err := m.writeTaskInfos(m.taskInfos)
		errCh <- err
	}
	return <-errCh
}

func (m *concreteManager) processFsFuncs() {
	defer m.logger.HandlePanic("Task Manager Process Fs Funcs")

	for {
		do := <-m.fsSem
		do()
	}
}

func (m *concreteManager) readTaskInfos() (map[string]TaskInfo, error) {
	taskInfos := make(map[string]TaskInfo)

	exists := m.fs.FileExists(m.tasksPath)
	if !exists {
		return taskInfos, nil
	}

	tasksJSON, err := m.fs.ReadFile(m.tasksPath)
	if err != nil {
		return nil, bosherr.WrapError(err, "Reading tasks json")
	}

	err = json.Unmarshal(tasksJSON, &taskInfos)
	if err != nil {
		return nil, bosherr.WrapError(err, "Unmarshaling tasks json")
	}

	return taskInfos, nil
}

func (m *concreteManager) writeTaskInfos(taskInfos map[string]TaskInfo) error {
	newTasksJSON, err := json.Marshal(taskInfos)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling tasks json")
	}

	err = m.fs.WriteFile(m.tasksPath, newTasksJSON)
	if err != nil {
		return bosherr.WrapError(err, "Writing tasks json")
	}

	return nil
}
