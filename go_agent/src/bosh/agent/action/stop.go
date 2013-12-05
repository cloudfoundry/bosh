package action

type stopAction struct{}

func newStop() (stop stopAction) {
	return
}

func (s stopAction) Run([]byte) (value interface{}, err error) {
	value = "stopped"
	return
}
