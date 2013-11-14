package action

import (
	boshtask "bosh/agent/task"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory(settings boshsettings.Settings, fs boshsys.FileSystem, taskService boshtask.Service) (factory concreteFactory) {
	factory.availableActions = map[string]Action{
		"apply":     newApply(fs),
		"ping":      newPing(),
		"get_task":  newGetTask(taskService),
		"get_state": newGetState(settings, fs),
	}

	return
}

func (f concreteFactory) Create(method string) (action Action) {
	return f.availableActions[method]
}
