package client

import (
	davconf "bosh/davcli/config"
	"crypto/sha1"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"strings"
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

func (c client) createReq(method, blobId string, body io.Reader) (req *http.Request, err error) {
	blobUrl, err := url.Parse(c.config.Endpoint)
	if err != nil {
		return
	}

	digester := sha1.New()
	digester.Write([]byte(blobId))
	blobPrefix := fmt.Sprintf("%02x", digester.Sum(nil)[0])

	newPath := path.Join(blobUrl.Path, blobPrefix, blobId)
	if !strings.HasPrefix(newPath, "/") {
		newPath = "/" + newPath
	}

	blobUrl.Path = newPath

	req, err = http.NewRequest(method, blobUrl.String(), body)
	if err != nil {
		return
	}

	req.SetBasicAuth(c.config.User, c.config.Password)
	return
}
