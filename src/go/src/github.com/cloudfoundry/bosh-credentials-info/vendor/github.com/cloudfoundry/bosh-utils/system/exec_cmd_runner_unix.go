// +build !windows

package system

import (
	"os/exec"
	"strings"
)

func newExecCmd(name string, args ...string) *exec.Cmd {
	return exec.Command(name, args...)
}

// mergeEnv merges system and command environments variables.  Command variables
// override any system variable with the same key.
func mergeEnv(sysEnv []string, cmdEnv map[string]string) []string {
	var env []string
	// cmdEnv has precedence and overwrites any duplicate vars
	for k, v := range cmdEnv {
		env = append(env, k+"="+v)
	}
	for _, s := range sysEnv {
		if n := strings.IndexByte(s, '='); n != -1 {
			k := s[:n] // key
			if _, found := cmdEnv[k]; !found {
				env = append(env, s)
			}
		}
	}
	return env
}
