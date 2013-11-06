package agent

import (
	"bosh/mbus"
	"time"
)

type agent struct {
	mbusHandler       mbus.Handler
	heartbeatInterval time.Duration
}

func New(mbusHandler mbus.Handler) (a agent) {
	a.mbusHandler = mbusHandler
	a.heartbeatInterval = time.Minute
	return
}

func (a agent) Run() (err error) {
	errChan := make(chan error, 1)
	heartbeatChan := make(chan mbus.Heartbeat, 1)

	go a.runMbusHandler(errChan)
	go a.generateHeartbeats(heartbeatChan)
	go a.sendHeartbeats(heartbeatChan, errChan)

	select {
	case err = <-errChan:
	}
	return
}

func (a agent) runMbusHandler(errChan chan error) {
	handlerFunc := func(req mbus.Request) (resp mbus.Response) {
		resp.Value = "pong"
		return
	}
	errChan <- a.mbusHandler.Run(handlerFunc)
}

func (a agent) generateHeartbeats(heartbeatChan chan mbus.Heartbeat) {
	tickChan := time.Tick(a.heartbeatInterval)
	for {
		select {
		case <-tickChan:
			heartbeatChan <- mbus.Heartbeat{}
		}
	}
}

func (a agent) sendHeartbeats(heartbeatChan chan mbus.Heartbeat, errChan chan error) {
	errChan <- a.mbusHandler.SendPeriodicHeartbeat(heartbeatChan)
}
