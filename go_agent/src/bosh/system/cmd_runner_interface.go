package system

type Command struct {
	Name       string
	Args       []string
	Env        map[string]string
	WorkingDir string
}

type CmdRunner interface {
	// RunComplexCommand returns error as nil:
	//  - command runs and exits with a zero exit status
	// RunComplexCommand returns error:
	//  - command runs and exits with a non-zero exit status
	//  - command does not run
	RunComplexCommand(cmd Command) (stdout, stderr string, exitStatus int, err error)

	RunCommand(cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	CommandExists(cmdName string) (exists bool)
}
