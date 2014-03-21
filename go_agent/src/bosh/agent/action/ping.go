package action

type PingAction struct{}

func NewPing() PingAction {
	return PingAction{}
}

func (a PingAction) IsAsynchronous() bool {
	return false
}

func (a PingAction) IsPersistent() bool {
	return false
}

func (a PingAction) Run() (interface{}, error) {
	return "pong", nil
}
