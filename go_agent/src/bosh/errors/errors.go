package errors

import (
	"errors"
	"fmt"
)

func WrapError(err error, msg string) (newErr error) {
	return errors.New(fmt.Sprintf("%s: %s", msg, err.Error()))
}
