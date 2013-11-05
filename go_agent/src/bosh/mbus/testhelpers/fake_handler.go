package testhelpers

import (
	"bosh/mbus"
)

type FakeHandler struct {
	Func mbus.HandlerFunc
}

func (h *FakeHandler) Run(handlerFunc mbus.HandlerFunc) (err error) {
	h.Func = handlerFunc
	return
}
