package fakes

import boshmbus "bosh/mbus"

type FakeHandler struct {
	ReceivedRun     bool
	ReceivedStart   bool
	ReceivedStop    bool
	AgentSubscribed bool
	Func            boshmbus.HandlerFunc

	SendToHealthManagerErr     error
	SendToHealthManagerTopic   string
	SendToHealthManagerPayload interface{}

	InitialHeartbeatSent bool
	TickHeartbeatsSent   bool
}

func NewFakeHandler() *FakeHandler {
	return &FakeHandler{}
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

func (h *FakeHandler) SendToHealthManager(topic string, payload interface{}) (err error) {
	if h.InitialHeartbeatSent {
		h.TickHeartbeatsSent = true
	}
	h.InitialHeartbeatSent = true
	h.SendToHealthManagerTopic = topic
	h.SendToHealthManagerPayload = payload
	err = h.SendToHealthManagerErr
	return
}
