package errors

import (
	"errors"
	"fmt"
)

func New(msg string, args ...interface{}) (err error) {
	return errors.New(fmt.Sprintf(msg, args...))
}

func WrapError(err error, msg string, args ...interface{}) (newErr error) {
	msg = fmt.Sprintf(msg, args...)
	return errors.New(fmt.Sprintf("%s: %s", msg, err.Error()))
}
