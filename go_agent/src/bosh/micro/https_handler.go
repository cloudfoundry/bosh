package micro

import (
	"encoding/base64"
	"io/ioutil"
	"net/http"
	"net/url"
	"path"

	"bosh/blobstore"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshdispatcher "bosh/httpsdispatcher"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type HTTPSHandler struct {
	parsedURL   *url.URL
	logger      boshlog.Logger
	dispatcher  boshdispatcher.HTTPSDispatcher
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func NewHTTPSHandler(
	parsedURL *url.URL,
	logger boshlog.Logger,
	fs boshsys.FileSystem,
	dirProvider boshdir.DirectoriesProvider,
) (handler HTTPSHandler) {
	handler.parsedURL = parsedURL
	handler.logger = logger
	handler.fs = fs
	handler.dirProvider = dirProvider
	handler.dispatcher = boshdispatcher.NewHTTPSDispatcher(parsedURL, logger)
	return
}

func (h HTTPSHandler) Run(handlerFunc boshhandler.HandlerFunc) error {
	err := h.Start(handlerFunc)
	if err != nil {
		return bosherr.WrapError(err, "Starting https handler")
	}
	return nil
}

func (h HTTPSHandler) Start(handlerFunc boshhandler.HandlerFunc) error {
	h.dispatcher.AddRoute("/agent", h.agentHandler(handlerFunc))
	h.dispatcher.AddRoute("/blobs/", h.blobsHandler())
	h.dispatcher.Start()
	return nil
}

func (h HTTPSHandler) Stop() {
	h.dispatcher.Stop()
}

func (h HTTPSHandler) RegisterAdditionalHandlerFunc(handlerFunc boshhandler.HandlerFunc) {
	panic("HTTPSHandler does not support registering additional handler funcs")
}

func (h HTTPSHandler) SendToHealthManager(topic string, payload interface{}) error {
	return nil
}

func (h HTTPSHandler) requestNotAuthorized(request *http.Request) bool {
	username := h.parsedURL.User.Username()
	password, _ := h.parsedURL.User.Password()
	auth := username + ":" + password
	expectedAuthorizationHeader := "Basic " + base64.StdEncoding.EncodeToString([]byte(auth))

	return expectedAuthorizationHeader != request.Header.Get("Authorization")
}

func (h HTTPSHandler) agentHandler(handlerFunc boshhandler.HandlerFunc) (agentHandler func(http.ResponseWriter, *http.Request)) {
	agentHandler = func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			w.WriteHeader(404)
			return
		}

		if h.requestNotAuthorized(r) {
			w.Header().Add("WWW-Authenticate", `Basic realm=""`)
			w.WriteHeader(401)
			return
		}

		rawJSONPayload, err := ioutil.ReadAll(r.Body)
		if err != nil {
			err = bosherr.WrapError(err, "Reading http body")
			return
		}

		respBytes, _, err := boshhandler.PerformHandlerWithJSON(
			rawJSONPayload,
			handlerFunc,
			boshhandler.UnlimitedResponseLength,
			h.logger,
		)
		if err != nil {
			err = bosherr.WrapError(err, "Running handler in a nice JSON sandwhich")
			return
		}

		w.Write(respBytes)
	}
	return
}

func (h HTTPSHandler) blobsHandler() (blobsHandler func(http.ResponseWriter, *http.Request)) {
	blobsHandler = func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			h.getBlob(w, r)
		case "PUT":
			h.putBlob(w, r)
		default:
			w.WriteHeader(404)
		}
		return
	}
	return
}

func (h HTTPSHandler) putBlob(w http.ResponseWriter, r *http.Request) {
	_, blobID := path.Split(r.URL.Path)
	blobManager := blobstore.NewBlobManager(h.fs, h.dirProvider)

	payload, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(500)
		w.Write([]byte(err.Error()))
		return
	}

	err = blobManager.Write(blobID, payload)
	if err != nil {
		w.WriteHeader(500)
		w.Write([]byte(err.Error()))
		return
	}

	w.WriteHeader(201)
}

func (h HTTPSHandler) getBlob(w http.ResponseWriter, r *http.Request) {
	_, blobID := path.Split(r.URL.Path)
	blobManager := blobstore.NewBlobManager(h.fs, h.dirProvider)

	blobBytes, err := blobManager.Fetch(blobID)

	if err != nil {
		w.WriteHeader(404)
	} else {
		w.Write(blobBytes)
	}
}

// Utils:

type concreteHTTPHandler struct {
	Callback func(http.ResponseWriter, *http.Request)
}

func (e concreteHTTPHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) { e.Callback(rw, r) }
