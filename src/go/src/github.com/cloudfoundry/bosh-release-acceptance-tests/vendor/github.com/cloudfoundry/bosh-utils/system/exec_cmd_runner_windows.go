package system

import "os/exec"

func newExecCmd(name string, args ...string) *exec.Cmd {
	args = append([]string{name}, args...)
	return exec.Command(`powershell`, args...)
}
