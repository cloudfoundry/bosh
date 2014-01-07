package client

import (
	davconf "bosh/davcli/config"
	"io"
	"net/http"
)

type Client interface {
	Get(path string) (content io.ReadCloser, err error)
	Put(path string, content io.ReadCloser) (err error)
}

func NewClient(config davconf.Config) (c Client) {
	return client{
		config:     config,
		httpClient: http.DefaultClient,
	}
}

type client struct {
	config     davconf.Config
	httpClient *http.Client
}

func (c client) Get(path string) (content io.ReadCloser, err error) {
	req, err := c.createReq("GET", path, nil)
	if err != nil {
		return
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return
	}

	content = resp.Body
	return
}

func (c client) Put(path string, content io.ReadCloser) (err error) {
	req, err := c.createReq("PUT", path, content)
	if err != nil {
		return
	}
	defer content.Close()

	_, err = c.httpClient.Do(req)
	return
}

func (c client) createReq(method, path string, body io.Reader) (req *http.Request, err error) {
	url := c.config.Endpoint + path

	req, err = http.NewRequest(method, url, body)
	if err != nil {
		return
	}

	req.SetBasicAuth(c.config.Username, c.config.Password)
	return
}
