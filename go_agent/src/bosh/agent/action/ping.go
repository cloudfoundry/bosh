package action

type pingAction struct{}

func newPing() (ping pingAction) {
	return
}

func (a pingAction) IsAsynchronous() bool {
	return false
}

func (a pingAction) Run() (value interface{}, err error) {
	value = "pong"
	return
}
