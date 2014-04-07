package testing

import (
	"encoding/base64"
	"errors"
	"net/http"
	"strings"
)

type HTTPRequest struct {
	*http.Request
}

func NewHTTPRequest(req *http.Request) (testReq HTTPRequest) {
	return HTTPRequest{req}
}

func (req HTTPRequest) ExtractBasicAuth() (username, password string, err error) {
	authHeader := req.Header["Authorization"]
	if len(authHeader) != 1 {
		err = errors.New("Missing basic auth header")
		return
	}

	encodedAuth := authHeader[0]
	encodedAuthParts := strings.Split(encodedAuth, " ")
	if len(encodedAuthParts) != 2 {
		err = errors.New("Invalid basic auth header format")
		return
	}

	clearAuth, err := base64.StdEncoding.DecodeString(encodedAuthParts[1])
	if len(encodedAuthParts) != 2 {
		err = errors.New("Invalid basic auth header encoding")
		return
	}

	clearAuthParts := strings.Split(string(clearAuth), ":")
	if len(clearAuthParts) != 2 {
		err = errors.New("Invalid basic auth header encoded username and pwd")
		return
	}

	username = clearAuthParts[0]
	password = clearAuthParts[1]
	return
}
