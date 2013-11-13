package mbus

import (
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
	client   yagnats.NATSClient
	settings boshsettings.Settings
}

func newNatsHandler(client yagnats.NATSClient, settings boshsettings.Settings) (handler natsHandler) {
	handler.client = client
	handler.settings = settings
	return
}

func (h natsHandler) Run(handlerFunc HandlerFunc) (err error) {
	err = h.Start(handlerFunc)
	if err != nil {
		return
	}
	defer h.Stop()

	h.runUntilInterrupted()
	return
}

func (h natsHandler) Start(handlerFunc HandlerFunc) (err error) {
	connProvider, err := h.getConnectionInfo()
	if err != nil {
		return
	}

	err = h.client.Connect(connProvider)
	if err != nil {
		return
	}

	subject := fmt.Sprintf("agent.%s", h.settings.AgentId)

	h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		req := Request{}
		err := json.Unmarshal([]byte(natsMsg.Payload), &req)
		if err != nil {
			return
		}
		req.payload = natsMsg.Payload

		resp := handlerFunc(req)

		respBytes, err := json.Marshal(resp)
		if err != nil {
			return
		}

		h.client.Publish(req.ReplyTo, string(respBytes))
	})

	return
}

func (h natsHandler) Stop() {
	h.client.Disconnect()
}

func (h natsHandler) SendPeriodicHeartbeat(heartbeatChan chan Heartbeat) (err error) {
	connProvider, err := h.getConnectionInfo()
	if err != nil {
		return
	}

	err = h.client.Connect(connProvider)
	if err != nil {
		return
	}

	heartbeatSubject := fmt.Sprintf("hm.agent.heartbeat.%s", h.settings.AgentId)

	var heartbeatBytes []byte
	for heartbeat := range heartbeatChan {
		heartbeatBytes, err = json.Marshal(heartbeat)
		if err != nil {
			return
		}

		h.client.Publish(heartbeatSubject, string(heartbeatBytes))
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
