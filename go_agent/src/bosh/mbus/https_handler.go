package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"encoding/base64"
	"errors"
	"io/ioutil"
	"net/http"
	"net/url"
	"crypto/tls"
	"net"
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
				w.Header().Add("WWW-Authenticate", `Basic realm=""`)
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

	listener, err := net.Listen("tcp", h.parsedURL.Host)
	if err != nil {
		return
	}

	httpServer := &http.Server{}
	mux := http.NewServeMux()
	httpServer.Handler = mux

	mux.HandleFunc("/agent", handler.Callback)

	mux.HandleFunc("/bar", func(writer http.ResponseWriter, request *http.Request) {
			defer request.Body.Close()
			writer.WriteHeader(201)
		})


	config := &tls.Config{}

	config.NextProtos = []string{"http/1.1"}

	config.Certificates = make([]tls.Certificate, 1)
	config.Certificates[0], err = tls.LoadX509KeyPair("agent.cert", "agent.key")
	if err != nil {
	err = bosherr.WrapError(err, "creating cert")
	return
	}

	tlsListener := tls.NewListener(listener, config)
	httpServer.Serve(tlsListener)

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
