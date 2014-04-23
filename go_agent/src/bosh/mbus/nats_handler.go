package mbus

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/cloudfoundry/yagnats"
	"net/url"
	"os"
	"os/signal"
	"syscall"

	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
)

const natsHandlerLogTag = "NATS Handler"

const (
	responseMaxSize       = 1024 * 1024
	responseMaxSizeErrMsg = "Response exceeded maximum size allowed to be sent over NATS"
)

type natsHandler struct {
	settings     boshsettings.Service
	logger       boshlog.Logger
	client       yagnats.NATSClient
	handlerFuncs []boshhandler.HandlerFunc
}

func NewNatsHandler(settings boshsettings.Service, logger boshlog.Logger, client yagnats.NATSClient) *natsHandler {
	return &natsHandler{
		settings: settings,
		logger:   logger,
		client:   client,
	}
}

func (h *natsHandler) Run(handlerFunc boshhandler.HandlerFunc) error {
	err := h.Start(handlerFunc)
	if err != nil {
		return bosherr.WrapError(err, "Starting nats handler")
	}
	defer h.Stop()

	h.runUntilInterrupted()

	return nil
}

func (h *natsHandler) Start(handlerFunc boshhandler.HandlerFunc) error {
	h.RegisterAdditionalHandlerFunc(handlerFunc)

	connProvider, err := h.getConnectionInfo()
	if err != nil {
		return bosherr.WrapError(err, "Getting connection info")
	}

	err = h.client.Connect(connProvider)
	if err != nil {
		return bosherr.WrapError(err, "Connecting")
	}

	subject := fmt.Sprintf("agent.%s", h.settings.GetAgentID())

	h.logger.Error(natsHandlerLogTag, "Subscribing to %s", subject)

	_, err = h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		for _, handlerFunc := range h.handlerFuncs {
			h.handleNatsMsg(natsMsg, handlerFunc)
		}
	})

	return nil
}

func (h *natsHandler) RegisterAdditionalHandlerFunc(handlerFunc boshhandler.HandlerFunc) {
	// Currently not locking since RegisterAdditionalHandlerFunc is not a primary way of adding handlerFunc
	h.handlerFuncs = append(h.handlerFuncs, handlerFunc)
}

func (h natsHandler) SendToHealthManager(topic string, payload interface{}) error {
	msgBytes := []byte("")

	if payload != nil {
		var err error
		msgBytes, err = json.Marshal(payload)
		if err != nil {
			return bosherr.WrapError(err, "Marshalling HM message payload")
		}
	}

	h.logger.Info(natsHandlerLogTag, "Sending HM message '%s'", topic)
	h.logger.DebugWithDetails(natsHandlerLogTag, "Payload", msgBytes)

	subject := fmt.Sprintf("hm.agent.%s.%s", topic, h.settings.GetAgentID())
	return h.client.Publish(subject, msgBytes)
}

func (h natsHandler) Stop() {
	h.client.Disconnect()
}

func (h natsHandler) handleNatsMsg(natsMsg *yagnats.Message, handlerFunc boshhandler.HandlerFunc) {
	respBytes, req, err := boshhandler.PerformHandlerWithJSON(natsMsg.Payload, handlerFunc, h.logger)
	if err != nil {
		h.logger.Error(natsHandlerLogTag, "Running handler: %s", err)
		return
	}

	if len(respBytes) > responseMaxSize {
		respBytes, err = boshhandler.BuildErrorWithJSON(responseMaxSizeErrMsg, h.logger)
		if err != nil {
			h.logger.Error(natsHandlerLogTag, "Building response: %s", err)
			return
		}
	}

	if len(respBytes) > 0 {
		h.client.Publish(req.ReplyTo, respBytes)
	}
}

func (h natsHandler) runUntilInterrupted() {
	defer h.client.Disconnect()

	keepRunning := true

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	for keepRunning {
		select {
		case <-c:
			keepRunning = false
		}
	}
}

func (h natsHandler) getConnectionInfo() (*yagnats.ConnectionInfo, error) {
	natsURL, err := url.Parse(h.settings.GetMbusURL())
	if err != nil {
		return nil, bosherr.WrapError(err, "Parsing Nats URL")
	}

	connInfo := new(yagnats.ConnectionInfo)
	connInfo.Addr = natsURL.Host

	user := natsURL.User
	if user != nil {
		password, passwordIsSet := user.Password()
		if !passwordIsSet {
			return nil, errors.New("No password set for connection")
		}
		connInfo.Password = password
		connInfo.Username = user.Username()
	}

	return connInfo, nil
}
