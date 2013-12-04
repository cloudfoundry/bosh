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
	settings boshsettings.Settings
	logger   boshlog.Logger
	client   yagnats.NATSClient
}

func newNatsHandler(settings boshsettings.Settings, logger boshlog.Logger, client yagnats.NATSClient) (handler natsHandler) {
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

	subject := fmt.Sprintf("agent.%s", h.settings.AgentId)

	h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		req := Request{}
		err := json.Unmarshal(natsMsg.Payload, &req)
		if err != nil {
			err = bosherr.WrapError(err, "Unmarshalling JSON payload")
			return
		}
		req.payload = natsMsg.Payload

		h.logger.Info("NATS Handler", "Received request with action %s", req.Method)
		h.logger.Debug("NATS Handler", "Payload \n********************\n%s\n********************", req.payload)

		resp := handlerFunc(req)
		respBytes, err := json.Marshal(resp)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling JSON response")
			return
		}

		h.logger.Info("NATS Handler", "Responding")
		h.logger.Debug("NATS Handler", "Payload \n********************\n%s\n********************", respBytes)

		h.client.Publish(req.ReplyTo, respBytes)
	})

	return
}

func (h natsHandler) Stop() {
	h.client.Disconnect()
}

func (h natsHandler) SendPeriodicHeartbeat(heartbeatChan chan Heartbeat) (err error) {
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

	heartbeatSubject := fmt.Sprintf("hm.agent.heartbeat.%s", h.settings.AgentId)

	var heartbeatBytes []byte
	for heartbeat := range heartbeatChan {
		heartbeatBytes, err = json.Marshal(heartbeat)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling heartbeat")
			return
		}

		h.logger.Info("NATS Handler", "Sending heartbeat")
		h.logger.Debug("NATS Handler", "Payload \n********************\n%s\n********************", heartbeatBytes)

		h.client.Publish(heartbeatSubject, heartbeatBytes)
	}

	return
}

func (h natsHandler) runUntilInterrupted() {
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
	natsUrl, err := url.Parse(h.settings.Mbus)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing Nats URL")
		return
	}

	user := natsUrl.User
	if user == nil {
		err = errors.New("No username or password set for connection")
		return
	}

	password, passwordIsSet := user.Password()
	if !passwordIsSet {
		err = errors.New("No password set for connection")
		return
	}

	connInfo = new(yagnats.ConnectionInfo)
	connInfo.Password = password
	connInfo.Username = user.Username()
	connInfo.Addr = natsUrl.Host

	return
}
