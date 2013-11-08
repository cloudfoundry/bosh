package agent

import (
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"time"
)

type agent struct {
	settings          boshsettings.Settings
	mbusHandler       boshmbus.Handler
	platform          boshplatform.Platform
	heartbeatInterval time.Duration
}

func New(settings boshsettings.Settings, mbusHandler boshmbus.Handler, platform boshplatform.Platform) (a agent) {
	a.settings = settings
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.heartbeatInterval = time.Minute
	return
}

func (a agent) Run() (err error) {
	errChan := make(chan error, 1)
	heartbeatChan := make(chan boshmbus.Heartbeat, 1)

	go a.runMbusHandler(errChan)
	go a.generateHeartbeats(heartbeatChan)
	go a.sendHeartbeats(heartbeatChan, errChan)

	select {
	case err = <-errChan:
	}
	return
}

func (a agent) runMbusHandler(errChan chan error) {
	handlerFunc := func(req boshmbus.Request) (resp boshmbus.Response) {
		resp.Value = "pong"
		return
	}
	errChan <- a.mbusHandler.Run(handlerFunc)
}

func (a agent) generateHeartbeats(heartbeatChan chan boshmbus.Heartbeat) {
	tickChan := time.Tick(a.heartbeatInterval)
	heartbeatChan <- getHeartbeat(a.settings, a.platform.GetStatsCollector())
	for {
		select {
		case <-tickChan:
			heartbeatChan <- getHeartbeat(a.settings, a.platform.GetStatsCollector())
		}
	}
}

func (a agent) sendHeartbeats(heartbeatChan chan boshmbus.Heartbeat, errChan chan error) {
	errChan <- a.mbusHandler.SendPeriodicHeartbeat(heartbeatChan)
}
