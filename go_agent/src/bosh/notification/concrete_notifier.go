package notification

import (
	boshhandler "bosh/handler"
)

type concreteNotifier struct {
	handler boshhandler.Handler
}

func NewNotifier(handler boshhandler.Handler) Notifier {
	return concreteNotifier{handler: handler}
}

func (n concreteNotifier) NotifyShutdown() error {
	return n.handler.SendToHealthManager("shutdown", nil)
}
