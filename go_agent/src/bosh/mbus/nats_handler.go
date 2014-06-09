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

const (
	natsHandlerLogTag = "NATS Handler"
	responseMaxLength = 1024 * 1024
)

type natsHandler struct {
	settingsService boshsettings.Service
	client          yagnats.NATSClient
	logger          boshlog.Logger
	handlerFuncs    []boshhandler.HandlerFunc
}

func NewNatsHandler(
	settingsService boshsettings.Service,
	client yagnats.NATSClient,
	logger boshlog.Logger,
) *natsHandler {
	return &natsHandler{
		settingsService: settingsService,
		client:          client,
		logger:          logger,
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

	settings := h.settingsService.GetSettings()

	subject := fmt.Sprintf("agent.%s", settings.AgentID)

	h.logger.Error(natsHandlerLogTag, "Subscribing to %s", subject)

	_, err = h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		for _, handlerFunc := range h.handlerFuncs {
			h.handleNatsMsg(natsMsg, handlerFunc)
		}
	})

	return nil
}

func (h *natsHandler) RegisterAdditionalHandlerFunc(handlerFunc boshhandler.HandlerFunc) {
	// Currently not locking since RegisterAdditionalHandlerFunc
	// is not a primary way of adding handlerFunc.
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

	settings := h.settingsService.GetSettings()

	subject := fmt.Sprintf("hm.agent.%s.%s", topic, settings.AgentID)
	return h.client.Publish(subject, msgBytes)
}

func (h natsHandler) Stop() {
	h.client.Disconnect()
}

func (h natsHandler) handleNatsMsg(natsMsg *yagnats.Message, handlerFunc boshhandler.HandlerFunc) {
	respBytes, req, err := boshhandler.PerformHandlerWithJSON(
		natsMsg.Payload,
		handlerFunc,
		responseMaxLength,
		h.logger,
	)
	if err != nil {
		h.logger.Error(natsHandlerLogTag, "Running handler: %s", err)
		return
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
	settings := h.settingsService.GetSettings()

	natsURL, err := url.Parse(settings.Mbus)
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
