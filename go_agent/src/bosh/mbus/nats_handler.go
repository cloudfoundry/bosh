package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/cloudfoundry/yagnats"
	"net/url"
	"os"
	"os/signal"
	"syscall"
)

type natsHandler struct {
	settings boshsettings.Service
	logger   boshlog.Logger
	client   yagnats.NATSClient
}

func newNatsHandler(settings boshsettings.Service, logger boshlog.Logger, client yagnats.NATSClient) (handler natsHandler) {
	handler.settings = settings
	handler.logger = logger
	handler.client = client
	return
}

func (h natsHandler) Run(handlerFunc HandlerFunc) (err error) {
	err = h.Start(handlerFunc)
	if err != nil {
		err = bosherr.WrapError(err, "Starting nats handler")
		return
	}
	defer h.Stop()

	h.runUntilInterrupted()
	return
}

func (h natsHandler) Start(handlerFunc HandlerFunc) (err error) {
	connProvider, err := h.getConnectionInfo()
	if err != nil {
		err = bosherr.WrapError(err, "Getting connection info")
		return
	}

	err = h.client.Connect(connProvider)
	if err != nil {
		err = bosherr.WrapError(err, "Connecting")
		return
	}

	subject := fmt.Sprintf("agent.%s", h.settings.GetAgentId())

	h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		respBytes, req, err := performHandlerWithJSON(natsMsg.Payload, handlerFunc, h.logger)
		if err != nil {
			err = bosherr.WrapError(err, "Running handler in a nice JSON sandwhich")
			return
		}

		h.client.Publish(req.ReplyTo, respBytes)
	})

	return
}

func (h natsHandler) SendToHealthManager(topic string, payload interface{}) (err error) {
	msgBytes := []byte("")

	if payload != nil {
		msgBytes, err = json.Marshal(payload)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling HM message payload")
			return
		}
	}

	h.logger.Info("NATS Handler", "Sending HM message '%s'", topic)
	h.logger.DebugWithDetails("NATS Handler", "Payload", msgBytes)

	subject := fmt.Sprintf("hm.agent.%s.%s", topic, h.settings.GetAgentId())
	return h.client.Publish(subject, msgBytes)
}

func (h natsHandler) Stop() {
	h.client.Disconnect()
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

func (h natsHandler) getConnectionInfo() (connInfo *yagnats.ConnectionInfo, err error) {
	natsUrl, err := url.Parse(h.settings.GetMbusUrl())
	if err != nil {
		err = bosherr.WrapError(err, "Parsing Nats URL")
		return
	}

	connInfo = new(yagnats.ConnectionInfo)
	connInfo.Addr = natsUrl.Host

	user := natsUrl.User
	if user != nil {
		password, passwordIsSet := user.Password()
		if !passwordIsSet {
			err = errors.New("No password set for connection")
			return
		}
		connInfo.Password = password
		connInfo.Username = user.Username()
	}

	return
}
