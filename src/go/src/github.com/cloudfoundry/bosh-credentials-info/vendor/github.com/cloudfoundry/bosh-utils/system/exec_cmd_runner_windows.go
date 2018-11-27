package system

import (
	"os/exec"
	"sort"
	"strings"
)

func newExecCmd(name string, args ...string) *exec.Cmd {
	return exec.Command(name, args...)
}

// mergeEnv case-insensitive merge of system and command environments variables.
// Command variables override any system variable with the same key.
func mergeEnv(sysEnv []string, cmdEnv map[string]string) []string {

	// sort keys so that duplicates are filtered in deterministic order
	keys := make([]string, 0, len(cmdEnv))
	for k := range cmdEnv {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var env []string
	seen := make(map[string]bool) // seen env keys

	// add vars from cmdEnv - skipping duplicates
	for _, k := range keys {
		v := cmdEnv[k] // value
		uk := strings.ToUpper(k)
		if !seen[uk] {
			env = append(env, k+"="+v)
			seen[uk] = true
		}
	}
	// add vars from sysEnv - skipping duplicates and keys present in cmdEnv
	for _, kv := range sysEnv {
		if n := strings.IndexByte(kv, '='); n != -1 {
			k := kv[:n] // key
			uk := strings.ToUpper(k)
			if !seen[uk] {
				env = append(env, kv)
				seen[uk] = true
			}
		}
	}
	return env
}
