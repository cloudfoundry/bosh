package action

type pingAction struct{}

func newPing() (ping pingAction) {
	return
}

func (a pingAction) Run([]byte) (value interface{}, err error) {
	value = "pong"
	return
}
