package action

type startAction struct{}

func newStart() (start startAction) {
	return
}

func (a startAction) IsAsynchronous() bool {
	return false
}

func (s startAction) Run() (value interface{}, err error) {
	value = "started"
	return
}
