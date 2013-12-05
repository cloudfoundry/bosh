package logger

import (
	"fmt"
	"log"
	"os"
	"runtime/debug"
)

type LogLevel int

const (
	LEVEL_DEBUG LogLevel = 0
	LEVEL_INFO  LogLevel = 1
	LEVEL_ERROR LogLevel = 2
	LEVEL_NONE  LogLevel = 99
)

type Logger struct {
	level LogLevel
	out   *log.Logger
	err   *log.Logger
}

func NewLogger(level LogLevel) (l Logger) {
	l.level = level
	l.out = log.New(os.Stdout, "", log.LstdFlags)
	l.err = log.New(os.Stderr, "", log.LstdFlags)
	return
}

func (l Logger) Debug(tag, msg string, args ...interface{}) {
	if l.level > LEVEL_DEBUG {
		return
	}

	msg = fmt.Sprintf("DEBUG - %s", msg)
	l.getOutLogger(tag).Printf(msg, args...)
}

// This will automatically change the format of the message to insert a block of text after the log
func (l Logger) DebugWithDetails(tag, msg string, args ...interface{}) {
	msg = msg + "\n********************\n%s\n********************"
	l.Debug(tag, msg, args...)
}

func (l Logger) Info(tag, msg string, args ...interface{}) {
	if l.level > LEVEL_INFO {
		return
	}

	msg = fmt.Sprintf("INFO - %s", msg)
	l.getOutLogger(tag).Printf(msg, args...)
}

func (l Logger) Error(tag, msg string, args ...interface{}) {
	if l.level > LEVEL_ERROR {
		return
	}

	msg = fmt.Sprintf("ERROR - %s", msg)
	l.getErrLogger(tag).Printf(msg, args...)
}

// This will automatically change the format of the message to insert a block of text after the log
func (l Logger) ErrorWithDetails(tag, msg string, args ...interface{}) {
	msg = msg + "\n********************\n%s\n********************"
	l.Error(tag, msg, args...)
}

func (l Logger) HandlePanic(tag string) {
	panic := recover()

	if panic != nil {
		var msg string

		switch obj := panic.(type) {
		case string:
			msg = obj
		case fmt.Stringer:
			msg = obj.String()
		case error:
			msg = obj.Error()
		default:
			msg = fmt.Sprintf("%#v", obj)
		}

		l.ErrorWithDetails(tag, "Panic: %s", msg, debug.Stack())
		os.Exit(2)
	}
}

func (l Logger) getOutLogger(tag string) (logger *log.Logger) {
	return l.updateLogger(l.out, tag)
}

func (l Logger) getErrLogger(tag string) (logger *log.Logger) {
	return l.updateLogger(l.err, tag)
}

func (l Logger) updateLogger(logger *log.Logger, tag string) *log.Logger {
	prefix := fmt.Sprintf("[%s] ", tag)
	logger.SetPrefix(prefix)
	return logger
}
