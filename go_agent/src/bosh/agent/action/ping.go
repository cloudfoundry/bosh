package action

type PingAction struct{}

func NewPing() (ping PingAction) {
	return
}

func (a PingAction) IsAsynchronous() bool {
	return false
}

func (a PingAction) Run() (value interface{}, err error) {
	value = "pong"
	return
}
