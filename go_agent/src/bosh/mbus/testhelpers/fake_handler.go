package testhelpers

import (
	"bosh/mbus"
)

type FakeHandler struct {
	ReceivedRun   bool
	ReceivedStart bool
	ReceivedStop  bool
	Func          mbus.HandlerFunc
}

func (h *FakeHandler) Run(handlerFunc mbus.HandlerFunc) (err error) {
	h.ReceivedRun = true
	h.Func = handlerFunc
	return
}

func (h *FakeHandler) Start(handlerFunc mbus.HandlerFunc) (err error) {
	h.ReceivedStart = true
	h.Func = handlerFunc
	return
}

func (h *FakeHandler) Stop() {
	h.ReceivedStop = true
}
