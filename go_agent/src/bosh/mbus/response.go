package mbus

import "fmt"

type Response interface {
	responseInterfaceFunc()
}

type valueResponse struct {
	Value interface{} `json:"value,omitempty"`
}

func NewValueResponse(value interface{}) (resp valueResponse) {
	resp.Value = value
	return
}

func (r valueResponse) responseInterfaceFunc() {
}

type exceptionResponse struct {
	Exception struct {
		Message string `json:"message,omitempty"`
	} `json:"exception"`
}

func NewExceptionResponse(msg string, args ...interface{}) (resp exceptionResponse) {
	resp.Exception.Message = fmt.Sprintf(msg, args...)
	return
}

func (r exceptionResponse) responseInterfaceFunc() {
}
