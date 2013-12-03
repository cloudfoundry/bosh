package action

type startAction struct{}

func newStart() (start startAction) {
	return
}

func (s startAction) Run([]byte) (value interface{}, err error) {
	value = "started"
	return
}
