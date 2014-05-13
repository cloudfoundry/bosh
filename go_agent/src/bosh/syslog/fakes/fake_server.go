package fakes

import (
	boshsyslog "bosh/syslog"
)

type FakeServer struct {
	StartFirstSyslogMsg *boshsyslog.Msg
	StartErr            error

	StopErr error
}

func (s *FakeServer) Start(callback boshsyslog.CallbackFunc) error {
	if s.StartFirstSyslogMsg != nil {
		callback(*s.StartFirstSyslogMsg)
	}

	return s.StartErr
}

func (s *FakeServer) Stop() error {
	return s.StopErr
}
