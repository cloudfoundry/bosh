package action

type drainAction struct{}

func newDrain() (drain drainAction) {
	return
}

func (s drainAction) Run([]byte) (value interface{}, err error) {
	value = 0
	return
}
