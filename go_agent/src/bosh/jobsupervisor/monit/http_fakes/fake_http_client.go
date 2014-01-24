package http_fakes

import (
	"bytes"
	"io"
	"net/http"
)

type FakeHttpClient struct {
	StatusCode        int
	Response          http.Response
	CallCount         int
	Error             error
	returnNilResponse bool
}

type nopCloser struct {
	io.Reader
}

func (nopCloser) Close() error { return nil }

func NewFakeHttpClient() (fakeHttpClient *FakeHttpClient) {
	fakeHttpClient = &FakeHttpClient{}
	return
}

func (c *FakeHttpClient) SetMessage(message string) {
	c.Response = http.Response{Body: nopCloser{bytes.NewBufferString(message)}}
}

func (c *FakeHttpClient) SetNilResponse() {
	c.returnNilResponse = true
}

func (c *FakeHttpClient) Do(req *http.Request) (resp *http.Response, err error) {
	c.CallCount++
	c.Response.StatusCode = c.StatusCode
	if !c.returnNilResponse {
		resp = &c.Response
	}
	err = c.Error
	return
}
