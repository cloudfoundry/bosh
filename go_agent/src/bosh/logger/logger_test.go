package logger_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"regexp"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/logger"
)

func expectedLogFormat(tag, msg string) string {
	return fmt.Sprintf("\\[%s\\] [0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} %s\n", tag, msg)
}

func captureOutputs(f func()) (stdout, stderr []byte) {
	oldStdout := os.Stdout
	oldStderr := os.Stderr

	rOut, wOut, err := os.Pipe()
	Expect(err).ToNot(HaveOccurred())

	rErr, wErr, err := os.Pipe()
	Expect(err).ToNot(HaveOccurred())

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

	err = wOut.Close()
	Expect(err).ToNot(HaveOccurred())

	err = wErr.Close()
	Expect(err).ToNot(HaveOccurred())

	stdout = <-outC
	stderr = <-errC

	os.Stdout = oldStdout
	os.Stderr = oldStderr

	return
}

var _ = Describe("Logger", func() {
	It("info", func() {
		stdout, _ := captureOutputs(func() {
			logger := NewLogger(LevelInfo)
			logger.Info("TAG", "some %s info to log", "awesome")
		})

		matcher, _ := regexp.Compile(expectedLogFormat("TAG", "INFO - some awesome info to log"))
		Expect(matcher.Match(stdout)).To(BeTrue())
	})

	It("debug", func() {
		stdout, _ := captureOutputs(func() {
			logger := NewLogger(LevelDebug)
			logger.Debug("TAG", "some %s info to log", "awesome")
		})

		matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some awesome info to log"))
		Expect(matcher.Match(stdout)).To(BeTrue())
	})

	It("debug with details", func() {
		stdout, _ := captureOutputs(func() {
			logger := NewLogger(LevelDebug)
			logger.DebugWithDetails("TAG", "some info to log", "awesome")
		})

		matcher, _ := regexp.Compile(expectedLogFormat("TAG", "DEBUG - some info to log"))
		Expect(matcher.Match(stdout)).To(BeTrue())

		assert.Contains(GinkgoT(), string(stdout), "\n********************\nawesome\n********************")
	})

	It("error", func() {
		_, stderr := captureOutputs(func() {
			logger := NewLogger(LevelError)
			logger.Error("TAG", "some %s info to log", "awesome")
		})

		matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some awesome info to log"))
		Expect(matcher.Match(stderr)).To(BeTrue())
	})

	It("error with details", func() {
		_, stderr := captureOutputs(func() {
			logger := NewLogger(LevelError)
			logger.ErrorWithDetails("TAG", "some error to log", "awesome")
		})

		matcher, _ := regexp.Compile(expectedLogFormat("TAG", "ERROR - some error to log"))
		Expect(matcher.Match(stderr)).To(BeTrue())

		assert.Contains(GinkgoT(), string(stderr), "\n********************\nawesome\n********************")
	})

	It("log level debug", func() {
		stdout, stderr := captureOutputs(func() {
			logger := NewLogger(LevelDebug)
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
			logger := NewLogger(LevelInfo)
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
			logger := NewLogger(LevelError)
			logger.Debug("DEBUG", "some debug log")
			logger.Info("INFO", "some info log")
			logger.Error("ERROR", "some error log")
		})

		assert.NotContains(GinkgoT(), string(stdout), "DEBUG")
		assert.NotContains(GinkgoT(), string(stdout), "INFO")
		assert.Contains(GinkgoT(), string(stderr), "ERROR")
	})
})
