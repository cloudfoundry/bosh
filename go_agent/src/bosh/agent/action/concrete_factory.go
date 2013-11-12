package action

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory() (factory concreteFactory) {
	factory.availableActions = map[string]Action{
		"apply": newApply(),
	}

	return
}

func (f concreteFactory) Create(method string) (action Action) {
	return f.availableActions[method]
}
