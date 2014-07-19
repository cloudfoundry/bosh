package fakes

import (
	cmdrunner "bosh/agent/cmdrunner"
	boshsys "bosh/system"
)

type FakeFileLoggingCmdRunner struct {
	BaseDir                string
	RunCommands            []boshsys.Command
	RunCommandResult       *cmdrunner.CmdResult
	RunCommandLogsDirName  string
	RunCommandLogsFileName string
	RunCommandErr          error
}

func NewFakeFileLoggingCmdRunner(baseDir string) *FakeFileLoggingCmdRunner {
	return &FakeFileLoggingCmdRunner{
		BaseDir: baseDir,
	}
}

func (f *FakeFileLoggingCmdRunner) RunCommand(logsDirName string, logsFileName string, cmd boshsys.Command) (*cmdrunner.CmdResult, error) {
	f.RunCommandLogsDirName = logsDirName
	f.RunCommandLogsFileName = logsFileName
	f.RunCommands = append(f.RunCommands, cmd)

	return f.RunCommandResult, f.RunCommandErr
}
