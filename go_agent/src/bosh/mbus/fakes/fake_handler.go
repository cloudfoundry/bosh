package fakes

import boshmbus "bosh/mbus"

type FakeHandler struct {
	SubscribedToDirector bool
	Func                 boshmbus.HandlerFunc

	SendToHealthManagerErr     error
	SendToHealthManagerTopic   string
	SendToHealthManagerPayload interface{}

	InitialHeartbeatSent bool
	TickHeartbeatsSent   bool
}

func NewFakeHandler() *FakeHandler {
	return &FakeHandler{}
}

func (h *FakeHandler) SubscribeToDirector(handlerFunc boshmbus.HandlerFunc) (err error) {
	h.SubscribedToDirector = true
	h.Func = handlerFunc
	return
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
