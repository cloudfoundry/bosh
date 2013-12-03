package logger

import (
	"fmt"
	"log"
	"os"
)

type LogLevel int

const (
	LEVEL_DEBUG LogLevel = 0
	LEVEL_INFO  LogLevel = 1
	LEVEL_ERROR LogLevel = 2
)

var (
	Level     LogLevel
	outLogger *log.Logger
	errLogger *log.Logger
)

func init() {
	resetLoggers()
}

func Debug(tag, msg string, args ...interface{}) {
	if Level > LEVEL_DEBUG {
		return
	}

	msg = fmt.Sprintf("DEBUG - %s", msg)
	getOutLogger(tag).Printf(msg, args...)
}

func Info(tag, msg string, args ...interface{}) {
	if Level > LEVEL_INFO {
		return
	}

	msg = fmt.Sprintf("INFO - %s", msg)
	getOutLogger(tag).Printf(msg, args...)
}

func Error(tag, msg string, args ...interface{}) {
	if Level > LEVEL_ERROR {
		return
	}

	msg = fmt.Sprintf("ERROR - %s", msg)
	getErrLogger(tag).Printf(msg, args...)
}

func resetLoggers() {
	outLogger = log.New(os.Stdout, "", log.LstdFlags)
	errLogger = log.New(os.Stderr, "", log.LstdFlags)
}

func getOutLogger(tag string) (logger *log.Logger) {
	return updateLogger(outLogger, tag)
}

func getErrLogger(tag string) (logger *log.Logger) {
	return updateLogger(errLogger, tag)
}

func updateLogger(logger *log.Logger, tag string) *log.Logger {
	prefix := fmt.Sprintf("[%s] ", tag)
	logger.SetPrefix(prefix)
	return logger
}
