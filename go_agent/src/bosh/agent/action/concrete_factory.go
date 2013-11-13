package action

import boshsys "bosh/system"

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory(fs boshsys.FileSystem) (factory concreteFactory) {
	factory.availableActions = map[string]Action{
		"apply": newApply(fs),
	}

	return
}

func (f concreteFactory) Create(method string) (action Action) {
	return f.availableActions[method]
}
