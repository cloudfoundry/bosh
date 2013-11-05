package mbus

import (
	"bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/cloudfoundry/yagnats"
	"net/url"
)

type natsHandler struct {
	client   yagnats.NATSClient
	settings settings.Settings
}

func newNatsHandler(client yagnats.NATSClient, s settings.Settings) (handler natsHandler) {
	handler.client = client
	handler.settings = s
	return
}

func (h natsHandler) Run(handlerFunc HandlerFunc) (err error) {
	connProvider, err := h.getConnectionInfo()
	if err != nil {
		return
	}

	h.client.Connect(connProvider)
	subject := fmt.Sprintf("agent.%s", h.settings.AgentId)

	h.client.Subscribe(subject, func(natsMsg *yagnats.Message) {
		req := Request{}
		err := json.Unmarshal([]byte(natsMsg.Payload), &req)
		if err != nil {
			return
		}

		resp := handlerFunc(req)

		respBytes, err := json.Marshal(resp)
		if err != nil {
			return
		}

		h.client.Publish(req.ReplyTo, string(respBytes))
	})

	return
}

func (h natsHandler) getConnectionInfo() (connInfo *yagnats.ConnectionInfo, err error) {
	natsUrl, err := url.Parse(h.settings.Mbus)
	if err != nil {
		return
	}

	password, passwordIsSet := natsUrl.User.Password()
	if !passwordIsSet {
		err = errors.New("No password set for connection")
		return
	}

	connInfo = new(yagnats.ConnectionInfo)
	connInfo.Password = password
	connInfo.Username = natsUrl.User.Username()
	connInfo.Addr = natsUrl.Host

	return
}
