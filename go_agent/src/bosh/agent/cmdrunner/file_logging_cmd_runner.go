package cmdrunner

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"unicode/utf8"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

const (
	fileOpenFlag int         = os.O_RDWR | os.O_CREATE | os.O_TRUNC
	fileOpenPerm os.FileMode = os.FileMode(0640)
)

type FileLoggingCmdRunner struct {
	fs             boshsys.FileSystem
	cmdRunner      boshsys.CmdRunner
	baseDir        string
	truncateLength int64
}

type FileLoggingExecErr struct {
	result *CmdResult
}

func (f FileLoggingExecErr) Error() string {
	stdoutTitle := "Stdout"
	if f.result.IsStdoutTruncated {
		stdoutTitle = "Truncated stdout"
	}

	stderrTitle := "Stderr"
	if f.result.IsStderrTruncated {
		stderrTitle = "Truncated stderr"
	}

	return fmt.Sprintf("Command exited with %d; %s: %s, %s: %s",
		f.result.ExitStatus,
		stdoutTitle,
		f.result.Stdout,
		stderrTitle,
		f.result.Stderr,
	)
}

func NewFileLoggingCmdRunner(
	fs boshsys.FileSystem,
	cmdRunner boshsys.CmdRunner,
	baseDir string,
	truncateLength int64,
) CmdRunner {
	return FileLoggingCmdRunner{
		fs:             fs,
		cmdRunner:      cmdRunner,
		baseDir:        baseDir,
		truncateLength: truncateLength,
	}
}

func (f FileLoggingCmdRunner) RunCommand(jobName string, taskName string, cmd boshsys.Command) (*CmdResult, error) {
	logsDir := filepath.Join(f.baseDir, jobName)

	err := f.fs.RemoveAll(logsDir)
	if err != nil {
		return nil, bosherr.WrapError(err, "Removing log dir for job %s", jobName)
	}

	err = f.fs.MkdirAll(logsDir, os.FileMode(0750))
	if err != nil {
		return nil, bosherr.WrapError(err, "Creating log dir for job %s", jobName)
	}

	stdoutPath := filepath.Join(logsDir, fmt.Sprintf("%s.stdout.log", taskName))
	stderrPath := filepath.Join(logsDir, fmt.Sprintf("%s.stderr.log", taskName))

	stdoutFile, err := f.fs.OpenFile(stdoutPath, fileOpenFlag, fileOpenPerm)
	if err != nil {
		return nil, bosherr.WrapError(err, "Opening stdout for task %s", taskName)
	}
	defer stdoutFile.Close()

	cmd.Stdout = stdoutFile

	stderrFile, err := f.fs.OpenFile(stderrPath, fileOpenFlag, fileOpenPerm)
	if err != nil {
		return nil, bosherr.WrapError(err, "Opening stderr for task %s", taskName)
	}
	defer stderrFile.Close()

	cmd.Stderr = stderrFile

	// Stdout/stderr are redirected to the files
	_, _, exitStatus, runErr := f.cmdRunner.RunComplexCommand(cmd)

	stdout, isStdoutTruncated, err := f.getTruncatedOutput(stdoutFile, f.truncateLength)
	if err != nil {
		return nil, bosherr.WrapError(err, "Truncating stdout for task %s", taskName)
	}

	stderr, isStderrTruncated, err := f.getTruncatedOutput(stderrFile, f.truncateLength)
	if err != nil {
		return nil, bosherr.WrapError(err, "Truncating stderr for task %s", taskName)
	}

	result := &CmdResult{
		IsStdoutTruncated: isStdoutTruncated,
		IsStderrTruncated: isStderrTruncated,

		Stdout: stdout,
		Stderr: stderr,

		ExitStatus: exitStatus,
	}

	if runErr != nil {
		return nil, FileLoggingExecErr{result}
	}

	return result, nil
}

func (f FileLoggingCmdRunner) getTruncatedOutput(file boshsys.ReadWriteCloseStater, truncateLength int64) ([]byte, bool, error) {
	isTruncated := false

	stat, err := file.Stat()
	if err != nil {
		return nil, false, err
	}

	resultSize := truncateLength
	offset := stat.Size() - truncateLength

	if offset < 0 {
		resultSize = stat.Size()
		offset = 0
	} else {
		isTruncated = true
	}

	data := make([]byte, resultSize)
	_, err = file.ReadAt(data, offset)
	if err != nil {
		return nil, false, err
	}

	// Do not truncate more than 25% of the data
	data = f.truncateUntilToken(data, truncateLength/int64(4))

	return data, isTruncated, nil
}

func (f FileLoggingCmdRunner) truncateUntilToken(data []byte, dataLossLimit int64) []byte {
	var i int64

	// Cut off until first line break unless it cuts off more allowed data loss
	if i = int64(bytes.IndexByte(data, '\n')); i >= 0 && i <= dataLossLimit {
		data = f.dropCR(data[i+1:])
	} else {
		// Make sure we don't break inside UTF encoded rune
		for {
			if len(data) < 1 {
				break
			}

			// Check for ASCII
			if data[0] < utf8.RuneSelf {
				break
			}

			// Check for UTF
			_, width := utf8.DecodeRune(data)
			if width > 1 && utf8.FullRune(data) {
				break
			}

			// Rune is not complete, check next
			data = data[1:]
		}
	}

	return data
}

func (f FileLoggingCmdRunner) dropCR(data []byte) []byte {
	if len(data) > 0 && data[0] == '\r' {
		return data[1:]
	}
	return data
}
