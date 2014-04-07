package errors

import (
	"fmt"
)

func New(msg string, args ...interface{}) error {
	return fmt.Errorf(msg, args...)
}

func WrapError(err error, msg string, args ...interface{}) error {
	return fmt.Errorf("%s: %s", fmt.Sprintf(msg, args...), err.Error())
}
