package cmdrunner

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"unicode/utf8"

	boshsys "bosh/system"
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

const (
	FileOpenFlag int         = os.O_RDWR | os.O_CREATE | os.O_TRUNC
	FileOpenPerm os.FileMode = os.FileMode(0640)
)

func NewFileLoggingCmdRunner(fs boshsys.FileSystem, cmdRunner boshsys.CmdRunner, baseDir string, truncateLength int64) CmdRunner {
	return FileLoggingCmdRunner{
		fs:             fs,
		cmdRunner:      cmdRunner,
		baseDir:        baseDir,
		truncateLength: truncateLength,
	}
}

func (f FileLoggingCmdRunner) RunCommand(logsDirName string, logsFileName string, cmd boshsys.Command) (*CmdResult, error) {
	logsDir := filepath.Join(f.baseDir, logsDirName)
	f.fs.RemoveAll(logsDir)
	err := f.fs.MkdirAll(logsDir, os.FileMode(0750))
	if err != nil {
		return nil, err
	}

	stdoutPath := filepath.Join(logsDir, fmt.Sprintf("%s.stdout.log", logsFileName))
	stdoutFile, err := f.fs.OpenFile(stdoutPath, FileOpenFlag, FileOpenPerm)
	if err != nil {
		return nil, err
	}
	defer stdoutFile.Close()

	cmd.Stdout = stdoutFile

	stderrPath := filepath.Join(logsDir, fmt.Sprintf("%s.stderr.log", logsFileName))
	stderrFile, err := f.fs.OpenFile(stderrPath, FileOpenFlag, FileOpenPerm)
	if err != nil {
		return nil, err
	}
	defer stderrFile.Close()

	cmd.Stderr = stderrFile

	// Stdout/stderr are redirected to the files
	_, _, exitStatus, runErr := f.cmdRunner.RunComplexCommand(cmd)

	stdout, isStdoutTruncated, err := getTruncatedOutput(stdoutFile, f.truncateLength)
	if err != nil {
		return nil, err
	}

	stderr, isStderrTruncated, err := getTruncatedOutput(stderrFile, f.truncateLength)
	if err != nil {
		return nil, err
	}

	result := &CmdResult{
		IsStdoutTruncated: isStdoutTruncated,
		IsStderrTruncated: isStderrTruncated,
		Stdout:            stdout,
		Stderr:            stderr,
		ExitStatus:        exitStatus,
	}

	if runErr != nil {
		return nil, FileLoggingExecErr{result}
	}

	return result, nil
}

func getTruncatedOutput(file boshsys.ReadWriteCloseStater, truncateLength int64) ([]byte, bool, error) {
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
	file.ReadAt(data, offset)

	dataLossLimit := truncateLength / int64(4)
	data = truncateUntilToken(data, dataLossLimit)

	return data, isTruncated, nil
}

func truncateUntilToken(data []byte, dataLossLimit int64) []byte {
	var i int64

	// Cut off until first line break unless it cuts off more allowed data loss
	if i = int64(bytes.IndexByte(data, '\n')); i >= 0 && i <= dataLossLimit {
		data = dropCR(data[i+1:])
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

func dropCR(data []byte) []byte {
	if len(data) > 0 && data[0] == '\r' {
		return data[1:]
	}
	return data
}
