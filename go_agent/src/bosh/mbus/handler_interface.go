package mbus

type HandlerFunc func(req Request) (resp Response)

type Handler interface {
	AgentSubscribe(handlerFunc HandlerFunc) (err error)
	SendPeriodicHeartbeat(heartbeatChan chan Heartbeat) (err error)
	NotifyShutdown() (err error)
}
