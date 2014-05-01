package httpsdispatcher

import (
	"crypto/tls"
	"net"
	"net/http"
	"net/url"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

type HTTPSDispatcher struct {
	logger     boshlog.Logger
	httpServer *http.Server
	mux        *http.ServeMux
	listener   net.Listener
}

type HTTPHandlerFunc func(writer http.ResponseWriter, request *http.Request)

func NewHTTPSDispatcher(baseURL *url.URL, logger boshlog.Logger) (dispatcher HTTPSDispatcher) {
	dispatcher.logger = logger

	dispatcher.httpServer = &http.Server{}
	dispatcher.mux = http.NewServeMux()
	dispatcher.httpServer.Handler = dispatcher.mux

	listener, err := net.Listen("tcp", baseURL.Host)
	if err != nil {
		err = bosherr.WrapError(err, "Create HTTP listener")
		return
	}
	dispatcher.listener = listener

	return
}

func (h HTTPSDispatcher) Start() (err error) {
	config := &tls.Config{}

	config.NextProtos = []string{"http/1.1"}

	config.Certificates = make([]tls.Certificate, 1)
	config.Certificates[0], err = tls.LoadX509KeyPair("agent.cert", "agent.key")
	if err != nil {
		err = bosherr.WrapError(err, "creating cert")
		return
	}
	tlsListener := tls.NewListener(h.listener, config)
	h.httpServer.Serve(tlsListener)

	return
}

func (h *HTTPSDispatcher) Stop() {
	h.listener.Close()
	return
}

func (h HTTPSDispatcher) AddRoute(route string, handler HTTPHandlerFunc) {
	h.mux.HandleFunc(route, handler)
	return
}
