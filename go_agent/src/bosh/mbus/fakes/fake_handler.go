package fakes

import boshmbus "bosh/mbus"

type FakeHandler struct {
	SubscribedToDirector bool
	Func                 boshmbus.HandlerFunc
	HeartbeatChan        chan boshmbus.Heartbeat

	NotifiedShutdown  bool
	NotifyShutdownErr error
}

func NewFakeHandler() *FakeHandler {
	return &FakeHandler{}
}

func (h *FakeHandler) SubscribeToDirector(handlerFunc boshmbus.HandlerFunc) (err error) {
	h.SubscribedToDirector = true
	h.Func = handlerFunc
	return
}

func (h *FakeHandler) SendPeriodicHeartbeat(heartbeatChan chan boshmbus.Heartbeat) (err error) {
	h.HeartbeatChan = heartbeatChan
	return
}

func (h *FakeHandler) NotifyShutdown() (err error) {
	h.NotifiedShutdown = true
	return h.NotifyShutdownErr
}
