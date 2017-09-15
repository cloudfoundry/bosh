package file_test

import (
	"errors"
	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/cloudfoundry/bosh-utils/logger/file"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	boshsys "github.com/cloudfoundry/bosh-utils/system"

	fakeboshsys "github.com/cloudfoundry/bosh-utils/system/fakes"
)

func expectedLogFormat(tag, msg string) string {
	return fmt.Sprintf("\\[%s\\] [0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} %s\n", tag, msg)
}

var _ = Describe("NewFileLogger", func() {
	var (
		fs      *fakeboshsys.FakeFileSystem
		logFile boshsys.File
	)

	BeforeEach(func() {
		fs = fakeboshsys.NewFakeFileSystem()
		var err error
		logFile, err = fs.TempFile("file-logger-test")
		Expect(err).ToNot(HaveOccurred())
		err = logFile.Close()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterEach(func() {
		logFile.Close()
		fs.RemoveAll(logFile.Name())
	})

	It("logs the formatted DEBUG message to the file", func() {
		logger, logFile, err := New(boshlog.LevelDebug, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).ToNot(HaveOccurred())

		logger.Debug("TAG", "some %s info to log", "awesome")

		contents, err := fs.ReadFileString(logFile.Name())
		Expect(err).ToNot(HaveOccurred())

		expectedContent := expectedLogFormat("TAG", "DEBUG - some awesome info to log")
		Expect(contents).To(MatchRegexp(expectedContent))
	})

	It("logs the formatted INFO message to the file", func() {
		logger, logFile, err := New(boshlog.LevelDebug, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).ToNot(HaveOccurred())

		logger.Info("TAG", "some %s info to log", "awesome")

		contents, err := fs.ReadFileString(logFile.Name())
		Expect(err).ToNot(HaveOccurred())

		expectedContent := expectedLogFormat("TAG", "INFO - some awesome info to log")
		Expect(contents).To(MatchRegexp(expectedContent))
	})

	It("logs the formatted WARN message to the file", func() {
		logger, logFile, err := New(boshlog.LevelDebug, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).ToNot(HaveOccurred())

		logger.Warn("TAG", "some %s info to log", "awesome")

		contents, err := fs.ReadFileString(logFile.Name())
		Expect(err).ToNot(HaveOccurred())

		expectedContent := expectedLogFormat("TAG", "WARN - some awesome info to log")
		Expect(contents).To(MatchRegexp(expectedContent))
	})

	It("logs the formatted ERROR message to the file", func() {
		logger, logFile, err := New(boshlog.LevelDebug, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).ToNot(HaveOccurred())

		logger.Error("TAG", "some %s info to log", "awesome")

		contents, err := fs.ReadFileString(logFile.Name())
		Expect(err).ToNot(HaveOccurred())

		expectedContent := expectedLogFormat("TAG", "ERROR - some awesome info to log")
		Expect(contents).To(MatchRegexp(expectedContent))
	})

	It("does not log at NONE level", func() {
		logger, logFile, err := New(boshlog.LevelNone, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).ToNot(HaveOccurred())

		logger.Error("TAG", "some %s info to log", "awesome")

		contents, err := fs.ReadFileString(logFile.Name())
		Expect(err).ToNot(HaveOccurred())

		Expect(contents).To(Equal(""))
	})

	It("errors if the file cannot be openned for writing", func() {
		fs.OpenFileErr = errors.New("fake-fs-error")

		_, _, err := New(boshlog.LevelNone, logFile.Name(), DefaultLogFileMode, fs)
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("fake-fs-error"))
	})
})
