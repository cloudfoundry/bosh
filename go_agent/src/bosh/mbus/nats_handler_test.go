package mbus

import (
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	"github.com/cloudfoundry/yagnats"
	"github.com/cloudfoundry/yagnats/fakeyagnats"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestNatsHandlerStart(t *testing.T) {
	client, handler := createNatsClientAndHandler()

	var receivedRequest Request

	handler.Start(func(req Request) (resp Response) {
		receivedRequest = req
		return NewValueResponse("expected value")
	})
	defer handler.Stop()

	// check connection
	assert.NotNil(t, client.ConnectedConnectionProvider)

	// check subscriptions
	assert.Equal(t, len(client.Subscriptions), 1)
	subscriptions := client.Subscriptions["agent.my-agent-id"]
	assert.Equal(t, len(subscriptions), 1)

	// test subscription callback
	expectedPayload := []byte(`{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`)
	subscription := client.Subscriptions["agent.my-agent-id"][0]
	subscription.Callback(&yagnats.Message{
		Subject: "agent.my-agent-id",
		Payload: expectedPayload,
	})

	// request received
	assert.Equal(t, receivedRequest, Request{
		ReplyTo: "reply to me!",
		Method:  "ping",
		payload: expectedPayload,
	})

	// response sent
	assert.Equal(t, len(client.PublishedMessages), 1)
	messages := client.PublishedMessages["reply to me!"]

	assert.Equal(t, len(messages), 1)
	message := messages[0]

	assert.Equal(t, []byte(`{"value":"expected value"}`), message.Payload)
}

func TestNatsSendPeriodicHeartbeat(t *testing.T) {
	heartbeatChan := make(chan Heartbeat, 1)
	client, handler := createNatsClientAndHandler()

	errChan := make(chan error, 1)

	go func() {
		errChan <- handler.SendPeriodicHeartbeat(heartbeatChan)
	}()

	heartbeatChan <- Heartbeat{Job: "foo", Index: 0}

	close(heartbeatChan)

	var err error
	select {
	case err = <-errChan:
	}
	assert.NoError(t, err)

	assert.Equal(t, len(client.PublishedMessages), 1)
	messages := client.PublishedMessages["hm.agent.heartbeat.my-agent-id"]

	assert.Equal(t, len(messages), 1)
	message := messages[0]

	expectedJson := `{"job":"foo","index":0,"job_state":"","vitals":{"cpu":{},"mem":{},"swap":{},"disk":{"system":{},"ephemeral":{},"persistent":{}}}}`
	assert.Equal(t, []byte(expectedJson), message.Payload)
}

func TestNatsHandlerConnectionInfo(t *testing.T) {
	_, handler := createNatsClientAndHandler()

	connInfo, err := handler.getConnectionInfo()
	assert.NoError(t, err)

	assert.Equal(t, connInfo.Addr, "127.0.0.1:1234")
	assert.Equal(t, connInfo.Username, "foo")
	assert.Equal(t, connInfo.Password, "bar")
}

func TestNatsHandlerConnectionInfoWithoutUsernameOrPassword(t *testing.T) {
	_, handler := createNatsClientAndHandler()
	handler.settings.Mbus = "nats://127.0.0.1:1234"

	_, err := handler.getConnectionInfo()
	assert.Error(t, err)
}

func TestNatsHandlerConnectionInfoWithoutPassword(t *testing.T) {
	_, handler := createNatsClientAndHandler()
	handler.settings.Mbus = "nats://foo@127.0.0.1:1234"

	_, err := handler.getConnectionInfo()
	assert.Error(t, err)
}

func createNatsClientAndHandler() (client *fakeyagnats.FakeYagnats, handler natsHandler) {
	settings := boshsettings.Settings{
		AgentId: "my-agent-id",
		Mbus:    "nats://foo:bar@127.0.0.1:1234",
	}

	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	client = fakeyagnats.New()
	handler = newNatsHandler(settings, logger, client)
	return
}
