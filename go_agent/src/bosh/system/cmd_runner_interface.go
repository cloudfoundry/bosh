package system

type CmdRunner interface {
	RunCommand(cmdName string, args ...string) (stdout, stderr string, err error)
	RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error)
}
