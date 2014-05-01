package fakes

import (
	"sync"

	boshhandler "bosh/handler"
)

type FakeHandler struct {
	RunFunc     boshhandler.HandlerFunc
	RunCallBack func()
	RunErr      error

	ReceivedRun   bool
	ReceivedStart bool
	ReceivedStop  bool

	// Keeps list of all receivd health manager requests
	hmRequestsLock sync.Mutex
	hmRequests     []HMRequest

	RegisteredAdditionalHandlerFunc boshhandler.HandlerFunc

	SendToHealthManagerCallBack func(HMRequest)
	SendToHealthManagerErr      error
}

type HMRequest struct {
	Topic   string
	Payload interface{}
}

func NewFakeHandler() *FakeHandler {
	return &FakeHandler{hmRequests: []HMRequest{}}
}

func (h *FakeHandler) Run(handlerFunc boshhandler.HandlerFunc) error {
	h.ReceivedRun = true
	h.RunFunc = handlerFunc

	if h.RunCallBack != nil {
		h.RunCallBack()
	}

	return h.RunErr
}

func (h *FakeHandler) KeepOnRunning() {
	block := make(chan error)
	h.RunCallBack = func() { <-block }
}

func (h *FakeHandler) Start(handlerFunc boshhandler.HandlerFunc) error {
	h.ReceivedStart = true
	h.RunFunc = handlerFunc
	return nil
}

func (h *FakeHandler) Stop() {
	h.ReceivedStop = true
}

func (h *FakeHandler) RegisterAdditionalHandlerFunc(handlerFunc boshhandler.HandlerFunc) {
	h.RegisteredAdditionalHandlerFunc = handlerFunc
}

func (h *FakeHandler) SendToHealthManager(topic string, payload interface{}) error {
	h.hmRequestsLock.Lock()
	defer h.hmRequestsLock.Unlock()

	hmRequest := HMRequest{topic, payload}
	h.hmRequests = append(h.hmRequests, hmRequest)

	if h.SendToHealthManagerCallBack != nil {
		h.SendToHealthManagerCallBack(hmRequest)
	}

	return h.SendToHealthManagerErr
}

func (h *FakeHandler) HMRequests() []HMRequest {
	h.hmRequestsLock.Lock()
	defer h.hmRequestsLock.Unlock()

	return h.hmRequests
}
