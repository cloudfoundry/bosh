// +build !windows

package system

import "os/exec"

func newExecCmd(name string, args ...string) *exec.Cmd {
	return exec.Command(name, args...)
}
