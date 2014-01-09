package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"encoding/base64"
	"errors"
	"io/ioutil"
	"net/http"
	"net/url"
)

type httpsHandler struct {
	parsedURL *url.URL
	logger    boshlog.Logger
}

func newHttpsHandler(parsedURL *url.URL, logger boshlog.Logger) (handler httpsHandler) {
	handler.parsedURL = parsedURL
	handler.logger = logger
	return
}

func (h httpsHandler) Run(handlerFunc HandlerFunc) (err error) {
	err = h.Start(handlerFunc)
	if err != nil {
		err = bosherr.WrapError(err, "Starting https handler")
		return
	}
	return
}

func (h httpsHandler) Start(handlerFunc HandlerFunc) (err error) {
	handler := concreteHTTPHandler{
		Callback: func(w http.ResponseWriter, r *http.Request) {
			if resourceNotFound(r) {
				err = bosherr.WrapError(errors.New("URL or Method not found"), "Handle HTTP")
				w.WriteHeader(404)
				return
			}

			if h.requestNotAuthorized(r) {
				err = bosherr.WrapError(errors.New("Incorrect Basic Auth"), "Handle HTTP")
				w.WriteHeader(401)
				return
			}

			rawJSONPayload, err := ioutil.ReadAll(r.Body)
			if err != nil {
				err = bosherr.WrapError(err, "Reading http body")
				return
			}

			respBytes, _, err := performHandlerWithJSON(rawJSONPayload, handlerFunc, h.logger)
			if err != nil {
				err = bosherr.WrapError(err, "Running handler in a nice JSON sandwhich")
				return
			}
			w.Write(respBytes)
		},
	}
	err = http.ListenAndServeTLS(h.parsedURL.Host, "agent.cert", "agent.key", handler)
	if err != nil {
		err = bosherr.WrapError(err, "Starting HTTP server")
		return
	}
	return
}

func (h httpsHandler) Stop() {
	return
}

func (h httpsHandler) SendToHealthManager(topic string, payload interface{}) (err error) {
	return
}

func (h httpsHandler) requestNotAuthorized(request *http.Request) bool {
	username := h.parsedURL.User.Username()
	password, _ := h.parsedURL.User.Password()
	auth := username + ":" + password
	expectedAuthorizationHeader := "Basic " + base64.StdEncoding.EncodeToString([]byte(auth))

	return expectedAuthorizationHeader != request.Header.Get("Authorization")
}

func resourceNotFound(request *http.Request) bool {
	return request.Method != "POST" || request.URL.Path != "/agent"
}

// Utils:

type concreteHTTPHandler struct {
	Callback func(http.ResponseWriter, *http.Request)
}

func (e concreteHTTPHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) { e.Callback(rw, r) }
