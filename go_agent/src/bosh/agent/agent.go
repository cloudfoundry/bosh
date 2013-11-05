package agent

import (
	"bosh/mbus"
)

type agent struct {
	mbusHandler mbus.Handler
}

func New(mbusHandler mbus.Handler) (a agent) {
	a.mbusHandler = mbusHandler
	return
}

func (a agent) Run() (err error) {
	handlerFunc := func(req mbus.Request) (resp mbus.Response) {
		resp.Value = "pong"
		return
	}

	err = a.mbusHandler.Run(handlerFunc)
	return
}
