package logger_test

import (
	. "bosh/logger"
	"fmt"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"os"
	"regexp"
)

func expectedLogFormat(tag, msg string) string {
	return fmt.Sprintf("\\[%s\\] [0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} %s\n", tag, msg)
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
func init() {
	Describe("Testing with Ginkgo", func() {
		It("info", func() {
			stdout, _ := captureOutputs(func() {
				logger := NewLogger(LEVEL_INFO)
				logger.Info("TAG", "some %s info to log", "awesome")
			})

			matcher, _ := regexp.Compile(expectedLogFormat("TAG", "INFO - some awesome info to log"))
			assert.True(GinkgoT(), matcher.Match(stdout))
		})
		It("debug", func() {

			stdout, _ := captureOutputs(func() {
				logger := NewLogger(LEVEL_DEBUG)
				logger.Debug("TAG", "some %s info to log", "awesome")
			})

			matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some awesome info to log"))
			assert.True(GinkgoT(), matcher.Match(stdout))
		})
		It("debug with details", func() {

			stdout, _ := captureOutputs(func() {
				logger := NewLogger(LEVEL_DEBUG)
				logger.DebugWithDetails("TAG", "some info to log", "awesome")
			})

			matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some info to log"))
			assert.True(GinkgoT(), matcher.Match(stdout))

			assert.Contains(GinkgoT(), string(stdout), "\n********************\nawesome\n********************")
		})
		It("error", func() {

			_, stderr := captureOutputs(func() {
				logger := NewLogger(LEVEL_ERROR)
				logger.Error("TAG", "some %s info to log", "awesome")
			})

			matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some awesome info to log"))
			assert.True(GinkgoT(), matcher.Match(stderr))
		})
		It("error with details", func() {

			_, stderr := captureOutputs(func() {
				logger := NewLogger(LEVEL_ERROR)
				logger.ErrorWithDetails("TAG", "some error to log", "awesome")
			})

			matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some error to log"))
			assert.True(GinkgoT(), matcher.Match(stderr))

			assert.Contains(GinkgoT(), string(stderr), "\n********************\nawesome\n********************")
		})
		It("log level debug", func() {

			stdout, stderr := captureOutputs(func() {
				logger := NewLogger(LEVEL_DEBUG)
				logger.Debug("DEBUG", "some debug log")
				logger.Info("INFO", "some info log")
				logger.Error("ERROR", "some error log")
			})

			assert.Contains(GinkgoT(), string(stdout), "DEBUG")
			assert.Contains(GinkgoT(), string(stdout), "INFO")
			assert.Contains(GinkgoT(), string(stderr), "ERROR")
		})
		It("log level info", func() {

			stdout, stderr := captureOutputs(func() {
				logger := NewLogger(LEVEL_INFO)
				logger.Debug("DEBUG", "some debug log")
				logger.Info("INFO", "some info log")
				logger.Error("ERROR", "some error log")
			})

			assert.NotContains(GinkgoT(), string(stdout), "DEBUG")
			assert.Contains(GinkgoT(), string(stdout), "INFO")
			assert.Contains(GinkgoT(), string(stderr), "ERROR")
		})
		It("log level error", func() {

			stdout, stderr := captureOutputs(func() {
				logger := NewLogger(LEVEL_ERROR)
				logger.Debug("DEBUG", "some debug log")
				logger.Info("INFO", "some info log")
				logger.Error("ERROR", "some error log")
			})

			assert.NotContains(GinkgoT(), string(stdout), "DEBUG")
			assert.NotContains(GinkgoT(), string(stdout), "INFO")
			assert.Contains(GinkgoT(), string(stderr), "ERROR")
		})
	})
}
