package action

import (
	boshtask "bosh/agent/task"
	boshsys "bosh/system"
)

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory(fs boshsys.FileSystem, taskService boshtask.Service) (factory concreteFactory) {
	factory.availableActions = map[string]Action{
		"apply":    newApply(fs),
		"ping":     newPing(),
		"get_task": newGetTask(taskService),
	}

	return
}

func (f concreteFactory) Create(method string) (action Action) {
	return f.availableActions[method]
}
