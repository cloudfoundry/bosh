package system

import (
	"fmt"
	"strings"
)

const (
	execErrorMsgFmt        = "Running command: '%s', stdout: '%s', stderr: '%s'"
	execShortErrorMaxLines = 100
)

type ExecError struct {
	Command string
	StdOut  string
	StdErr  string
}

func NewExecError(cmd, stdout, stderr string) ExecError {
	return ExecError{
		Command: cmd,
		StdOut:  stdout,
		StdErr:  stderr,
	}
}

func (e ExecError) Error() string {
	return fmt.Sprintf(execErrorMsgFmt, e.Command, e.StdOut, e.StdErr)
}

// ShortError returns an error message that has stdout/stderr truncated.
func (e ExecError) ShortError() string {
	outStr := e.truncateStr(e.StdOut, execShortErrorMaxLines)
	errStr := e.truncateStr(e.StdErr, execShortErrorMaxLines)
	return fmt.Sprintf(execErrorMsgFmt, e.Command, outStr, errStr)
}

func (e ExecError) truncateStr(in string, maxLines int) string {
	outLines := strings.Split(in, "\n")
	if i := len(outLines); i > maxLines {
		outLines = outLines[i-maxLines:]
	}

	return strings.Join(outLines, "\n")
}
