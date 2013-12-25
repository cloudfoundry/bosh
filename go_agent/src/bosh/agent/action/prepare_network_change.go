package action

type prepareNetworkChangeAction struct {
}

func newPrepareNetworkChange() (prepareAction prepareNetworkChangeAction) {
	return
}

func (p prepareNetworkChangeAction) IsAsynchronous() bool {
	return false
}

func (p prepareNetworkChangeAction) Run() (value interface{}, err error) {
	value = true
	return
}
