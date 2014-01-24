package notification

import boshhandler "bosh/handler"

type concreteNotifier struct {
	handler boshhandler.Handler
}

func NewNotifier(handler boshhandler.Handler) (notifier Notifier) {
	return concreteNotifier{
		handler: handler,
	}
}

func (n concreteNotifier) NotifyShutdown() (err error) {
	return n.handler.SendToHealthManager("shutdown", nil)
}
