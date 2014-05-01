package fakes

import (
	"bytes"
	"errors"
	"io"
	"net/http"
)

type FakeHTTPClient struct {
	StatusCode        int
	CallCount         int
	Error             error
	returnNilResponse bool
	RequestBodies     []string
	responseMessage   string
}

type nopCloser struct {
	io.Reader
}

func (nopCloser) Close() error { return nil }

type stringReadCloser struct {
	reader io.Reader
	closed bool
}

func (s *stringReadCloser) Close() error {
	s.closed = true
	return nil
}

func (s *stringReadCloser) Read(p []byte) (n int, err error) {
	if s.closed {
		return 0, errors.New("already closed")
	}

	return s.reader.Read(p)
}

func NewFakeHTTPClient() (fakeHTTPClient *FakeHTTPClient) {
	fakeHTTPClient = &FakeHTTPClient{}
	return
}

func (c *FakeHTTPClient) SetMessage(message string) {
	c.responseMessage = message
}

func (c *FakeHTTPClient) SetNilResponse() {
	c.returnNilResponse = true
}

func (c *FakeHTTPClient) Do(req *http.Request) (resp *http.Response, err error) {
	c.CallCount++

	if !c.returnNilResponse {
		resp = &http.Response{Body: &stringReadCloser{bytes.NewBufferString(c.responseMessage), false}}
		resp.StatusCode = c.StatusCode
	}
	err = c.Error

	buf := make([]byte, 1024)
	n, _ := req.Body.Read(buf)
	c.RequestBodies = append(c.RequestBodies, string(buf[0:n]))

	return
}
