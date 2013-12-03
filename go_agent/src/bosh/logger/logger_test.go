package logger

import (
	"fmt"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"os"
	"regexp"
	"testing"
)

func expectedLogFormat(tag, msg string) string {
	return fmt.Sprintf("\\[%s\\] [0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} %s\n", tag, msg)
}

func TestInfo(t *testing.T) {
	stdout, _ := captureOutputs(func() {
		Info("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "INFO - some awesome info to log"))
	assert.True(t, matcher.Match(stdout))
}

func TestDebug(t *testing.T) {
	stdout, _ := captureOutputs(func() {
		Debug("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some awesome info to log"))
	assert.True(t, matcher.Match(stdout))
}

func TestError(t *testing.T) {
	_, stderr := captureOutputs(func() {
		Error("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some awesome info to log"))
	assert.True(t, matcher.Match(stderr))
}

func TestLogLevelDebug(t *testing.T) {
	Level = LEVEL_DEBUG

	stdout, stderr := captureOutputs(func() {
		Debug("DEBUG", "some debug log")
		Info("INFO", "some info log")
		Error("ERROR", "some error log")
	})

	assert.Contains(t, string(stdout), "DEBUG")
	assert.Contains(t, string(stdout), "INFO")
	assert.Contains(t, string(stderr), "ERROR")
}

func TestLogLevelInfo(t *testing.T) {
	Level = LEVEL_INFO

	stdout, stderr := captureOutputs(func() {
		Debug("DEBUG", "some debug log")
		Info("INFO", "some info log")
		Error("ERROR", "some error log")
	})

	assert.NotContains(t, string(stdout), "DEBUG")
	assert.Contains(t, string(stdout), "INFO")
	assert.Contains(t, string(stderr), "ERROR")
}

func TestLogLevelError(t *testing.T) {
	Level = LEVEL_ERROR

	stdout, stderr := captureOutputs(func() {
		Debug("DEBUG", "some debug log")
		Info("INFO", "some info log")
		Error("ERROR", "some error log")
	})

	assert.NotContains(t, string(stdout), "DEBUG")
	assert.NotContains(t, string(stdout), "INFO")
	assert.Contains(t, string(stderr), "ERROR")
}

func captureOutputs(f func()) (stdout, stderr []byte) {
	oldStdout := os.Stdout
	oldStderr := os.Stderr

	rOut, wOut, _ := os.Pipe()
	rErr, wErr, _ := os.Pipe()

	os.Stdout = wOut
	os.Stderr = wErr

	resetLoggers()
	f()

	outC := make(chan []byte)
	errC := make(chan []byte)

	go func() {
		bytes, _ := ioutil.ReadAll(rOut)
		outC <- bytes

		bytes, _ = ioutil.ReadAll(rErr)
		errC <- bytes
	}()

	wOut.Close()
	wErr.Close()

	stdout = <-outC
	stderr = <-errC

	os.Stdout = oldStdout
	os.Stderr = oldStderr
	return
}
