package micro

import (
	"bosh/blobstore"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshhttps "bosh/https_dispatcher"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"encoding/base64"
	"io/ioutil"
	"net/http"
	"net/url"
	"path"
)

type HttpsHandler struct {
	parsedURL   *url.URL
	logger      boshlog.Logger
	dispatcher  boshhttps.HttpsDispatcher
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func NewHttpsHandler(parsedURL *url.URL, logger boshlog.Logger, fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (handler HttpsHandler) {
	handler.parsedURL = parsedURL
	handler.logger = logger
	handler.fs = fs
	handler.dirProvider = dirProvider
	handler.dispatcher = boshhttps.NewHttpsDispatcher(parsedURL, logger)

	return
}

func (h HttpsHandler) Run(handlerFunc boshhandler.HandlerFunc) (err error) {
	err = h.Start(handlerFunc)
	if err != nil {
		err = bosherr.WrapError(err, "Starting https handler")
		return
	}
	return
}

func (h HttpsHandler) Start(handlerFunc boshhandler.HandlerFunc) (err error) {
	h.dispatcher.AddRoute("/agent", h.agentHandler(handlerFunc))
	h.dispatcher.AddRoute("/blobs/", h.blobsHandler())
	h.dispatcher.Start()

	return
}

func (h HttpsHandler) Stop() {
	h.dispatcher.Stop()
	return
}

func (h HttpsHandler) SendToHealthManager(topic string, payload interface{}) (err error) {
	return
}

func (h HttpsHandler) requestNotAuthorized(request *http.Request) bool {
	username := h.parsedURL.User.Username()
	password, _ := h.parsedURL.User.Password()
	auth := username + ":" + password
	expectedAuthorizationHeader := "Basic " + base64.StdEncoding.EncodeToString([]byte(auth))

	return expectedAuthorizationHeader != request.Header.Get("Authorization")
}

func (h HttpsHandler) agentHandler(handlerFunc boshhandler.HandlerFunc) (agentHandler func(http.ResponseWriter, *http.Request)) {
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
		respBytes, _, err := boshhandler.PerformHandlerWithJSON(rawJSONPayload, handlerFunc, h.logger)
		if err != nil {
			err = bosherr.WrapError(err, "Running handler in a nice JSON sandwhich")
			return
		}
		w.Write(respBytes)
	}
	return
}

func (h HttpsHandler) blobsHandler() (blobsHandler func(http.ResponseWriter, *http.Request)) {
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

func (h HttpsHandler) putBlob(w http.ResponseWriter, r *http.Request) {
	_, blobId := path.Split(r.URL.Path)
	blobManager := blobstore.NewBlobManager(h.fs, h.dirProvider)

	payload, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(500)
		w.Write([]byte(err.Error()))
		return
	}

	err = blobManager.Write(blobId, payload)
	if err != nil {
		w.WriteHeader(500)
		w.Write([]byte(err.Error()))
		return
	}

	w.WriteHeader(201)
}

func (h HttpsHandler) getBlob(w http.ResponseWriter, r *http.Request) {
	_, blobId := path.Split(r.URL.Path)
	blobManager := blobstore.NewBlobManager(h.fs, h.dirProvider)

	blobBytes, err := blobManager.Fetch(blobId)

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
