package handler

import "fmt"

type Response interface {
	responseInterfaceFunc()
}

type valueResponse struct {
	Value interface{} `json:"value"`
}

func NewValueResponse(value interface{}) (resp Response) {
	resp = valueResponse{Value: value}
	return
}

func (r valueResponse) responseInterfaceFunc() {
}

type exceptionResponse struct {
	Exception struct {
		Message string `json:"message,omitempty"`
	} `json:"exception"`
}

func NewExceptionResponse(msg string, args ...interface{}) (resp Response) {
	r := exceptionResponse{}
	r.Exception.Message = fmt.Sprintf(msg, args...)
	return r
}

func (r exceptionResponse) responseInterfaceFunc() {
}
