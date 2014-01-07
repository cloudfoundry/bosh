package system

type Command struct {
	Name       string
	Args       []string
	Env        map[string]string
	WorkingDir string
}

type CmdRunner interface {
	RunComplexCommand(cmd Command) (stdout, stderr string, err error)
	RunCommand(cmdName string, args ...string) (stdout, stderr string, err error)
	RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, err error)
	CommandExists(cmdName string) (exists bool)
}
