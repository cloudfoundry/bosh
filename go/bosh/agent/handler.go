package agent

import (
	"errors"
)

type HandlerReturnValue interface{}
type HandlerErrorValue interface{}

// Any function can be a message handler if it conforms to HandleMessage signature
type MessageHandler func(s *server, args ...interface{}) (HandlerReturnValue, error)

var (
	ArgumentError  = errors.New("invalid arguments")
	BadStateFormat = errors.New("bad state format")
	NotImplemented = errors.New("not implemented")
)

func (mh MessageHandler) HandleMessage(s *server, args ...interface{}) (HandlerReturnValue, error) {
	return mh(s, args...)
}

func PingHandler(s *server, args ...interface{}) (HandlerReturnValue, error) {
	return "pong", nil
}

func GetStateHandler(s *server, args ...interface{}) (HandlerReturnValue, error) {
	st, err := ReadStateFromFile(s)
	if err != nil {
		return nil, err
	}

	return st, nil
}

func CompilePackageHandler(s *server, args ...interface{}) (HandlerReturnValue, error) {
	return nil, NotImplemented
}

func ApplyHandler(s *server, args ...interface{}) (HandlerReturnValue, error) {
	if len(args) != 1 {
		return nil, ArgumentError
	}

	newState, ok := args[0].(map[string]interface{})
	if !ok {
		return nil, BadStateFormat
	}

	// TODO: actually apply jobs and packages

	err := WriteState(s, newState)
	if err != nil {
		return nil, err
	}

	return "ok", nil
}
