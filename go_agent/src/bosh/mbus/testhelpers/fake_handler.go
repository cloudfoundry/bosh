package testhelpers

import boshmbus "bosh/mbus"

type FakeHandler struct {
	ReceivedRun   bool
	ReceivedStart bool
	ReceivedStop  bool
	Func          boshmbus.HandlerFunc
	HeartbeatChan chan boshmbus.Heartbeat
}

func (h *FakeHandler) Run(handlerFunc boshmbus.HandlerFunc) (err error) {
	h.ReceivedRun = true
	h.Func = handlerFunc
	return
}

func (h *FakeHandler) Start(handlerFunc boshmbus.HandlerFunc) (err error) {
	h.ReceivedStart = true
	h.Func = handlerFunc
	return
}

func (h *FakeHandler) Stop() {
	h.ReceivedStop = true
}

func (h *FakeHandler) SendPeriodicHeartbeat(heartbeatChan chan boshmbus.Heartbeat) (err error) {
	h.HeartbeatChan = heartbeatChan
	return
}
