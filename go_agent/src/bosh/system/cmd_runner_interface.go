package system

import (
	"time"
)

type Command struct {
	Name       string
	Args       []string
	Env        map[string]string
	WorkingDir string
}

type Process interface {
	// Wait is the only way to get back process result information.
	// It must not be called multiple times.
	Wait() <-chan Result

	// TerminateNicely can be called multiple times.
	// It must only be called after Wait().
	TerminateNicely(killGracePeriod time.Duration) error
}

type Result struct {
	Stdout     string
	Stderr     string
	ExitStatus int
	Error      error
}

type CmdRunner interface {
	// RunComplexCommand returns error as nil:
	//  - command runs and exits with a zero exit status
	// RunComplexCommand returns error:
	//  - command runs and exits with a non-zero exit status
	//  - command does not run
	RunComplexCommand(cmd Command) (stdout, stderr string, exitStatus int, err error)

	RunComplexCommandAsync(cmd Command) (Process, error)

	RunCommand(cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	RunCommandWithInput(input, cmdName string, args ...string) (stdout, stderr string, exitStatus int, err error)

	CommandExists(cmdName string) (exists bool)
}
