package http_fakes

import (
	"bytes"
	"io"
	"net/http"
)

type FakeHttpClient struct {
	StatusCode int
	response   http.Response
}

type nopCloser struct {
	io.Reader
}

func (nopCloser) Close() error { return nil }

func NewFakeHttpClient(statusCode int, message string) (fakeHttpClient *FakeHttpClient) {
	fakeHttpClient = &FakeHttpClient{
		StatusCode: statusCode,
		response: http.Response{
			Body: nopCloser{bytes.NewBufferString(message)},
		},
	}
	return
}

func (c *FakeHttpClient) Do(req *http.Request) (resp *http.Response, err error) {
	c.response.StatusCode = c.StatusCode
	resp = &c.response
	return
}
