package system

type Command struct {
	Name       string
	Args       []string
	Env        map[string]string
	WorkingDir string
}

type CmdRunner interface {
	// If command runs and exits with a zero exit status, error will be nil
	RunComplexCommand(cmd Command) (stdout, stderr string, exitStatus int, err error)

	RunCommand(cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	CommandExists(cmdName string) (exists bool)
}
