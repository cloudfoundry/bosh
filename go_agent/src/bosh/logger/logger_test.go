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
		logger := NewLogger(LEVEL_INFO)
		logger.Info("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "INFO - some awesome info to log"))
	assert.True(t, matcher.Match(stdout))
}

func TestDebug(t *testing.T) {
	stdout, _ := captureOutputs(func() {
		logger := NewLogger(LEVEL_DEBUG)
		logger.Debug("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some awesome info to log"))
	assert.True(t, matcher.Match(stdout))
}

func TestDebugWithDetails(t *testing.T) {
	stdout, _ := captureOutputs(func() {
		logger := NewLogger(LEVEL_DEBUG)
		logger.DebugWithDetails("TAG", "some info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some info to log"))
	assert.True(t, matcher.Match(stdout))

	assert.Contains(t, string(stdout), "\n********************\nawesome\n********************")
}

func TestError(t *testing.T) {
	_, stderr := captureOutputs(func() {
		logger := NewLogger(LEVEL_ERROR)
		logger.Error("TAG", "some %s info to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some awesome info to log"))
	assert.True(t, matcher.Match(stderr))
}

func TestErrorWithDetails(t *testing.T) {
	_, stderr := captureOutputs(func() {
		logger := NewLogger(LEVEL_ERROR)
		logger.ErrorWithDetails("TAG", "some error to log", "awesome")
	})

	matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some error to log"))
	assert.True(t, matcher.Match(stderr))

	assert.Contains(t, string(stderr), "\n********************\nawesome\n********************")
}

func TestLogLevelDebug(t *testing.T) {
	stdout, stderr := captureOutputs(func() {
		logger := NewLogger(LEVEL_DEBUG)
		logger.Debug("DEBUG", "some debug log")
		logger.Info("INFO", "some info log")
		logger.Error("ERROR", "some error log")
	})

	assert.Contains(t, string(stdout), "DEBUG")
	assert.Contains(t, string(stdout), "INFO")
	assert.Contains(t, string(stderr), "ERROR")
}

func TestLogLevelInfo(t *testing.T) {
	stdout, stderr := captureOutputs(func() {
		logger := NewLogger(LEVEL_INFO)
		logger.Debug("DEBUG", "some debug log")
		logger.Info("INFO", "some info log")
		logger.Error("ERROR", "some error log")
	})

	assert.NotContains(t, string(stdout), "DEBUG")
	assert.Contains(t, string(stdout), "INFO")
	assert.Contains(t, string(stderr), "ERROR")
}

func TestLogLevelError(t *testing.T) {
	stdout, stderr := captureOutputs(func() {
		logger := NewLogger(LEVEL_ERROR)
		logger.Debug("DEBUG", "some debug log")
		logger.Info("INFO", "some info log")
		logger.Error("ERROR", "some error log")
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
