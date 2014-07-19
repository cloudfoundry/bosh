package cmdrunner

import (
	boshsys "bosh/system"
)

type CmdResult struct {
	IsStdoutTruncated bool
	IsStderrTruncated bool
	Stdout            []byte
	Stderr            []byte
	ExitStatus        int
}

type CmdRunner interface {
	RunCommand(logsDirName string, logsFileName string, cmd boshsys.Command) (*CmdResult, error)
}
