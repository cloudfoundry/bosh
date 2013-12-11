package action

type stopAction struct{}

func newStop() (stop stopAction) {
	return
}

func (a stopAction) IsAsynchronous() bool {
	return true
}

func (s stopAction) Run() (value interface{}, err error) {
	value = "stopped"
	return
}
