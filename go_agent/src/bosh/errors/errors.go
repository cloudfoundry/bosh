package errors

import (
	"errors"
	"fmt"
)

func New(msg string, args ...interface{}) (err error) {
	return errors.New(fmt.Sprintf(msg, args...))
}

func WrapError(err error, msg string) (newErr error) {
	return errors.New(fmt.Sprintf("%s: %s", msg, err.Error()))
}
