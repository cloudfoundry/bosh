package notification

import boshmbus "bosh/mbus"

type concreteNotifier struct {
	handler boshmbus.Handler
}

func NewNotifier(handler boshmbus.Handler) (notifier Notifier) {
	return concreteNotifier{
		handler: handler,
	}
}

func (n concreteNotifier) NotifyShutdown() (err error) {
	return n.handler.SendToHealthManager("shutdown", nil)
}
