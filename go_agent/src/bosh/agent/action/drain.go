package action

type drainAction struct{}

func newDrain() (drain drainAction) {
	return
}

func (a drainAction) IsAsynchronous() bool {
	return true
}

func (s drainAction) Run() (value interface{}, err error) {
	value = 0
	return
}
