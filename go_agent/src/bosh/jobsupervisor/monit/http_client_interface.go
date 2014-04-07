package monit

import (
	"net/http"
)

type HTTPClient interface {
	Do(req *http.Request) (resp *http.Response, err error)
}
