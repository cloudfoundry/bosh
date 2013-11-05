package mbus

import (
	"bosh/settings"
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
		return Response{Value: "expected value"}
	})
	defer handler.Stop()

	// check connection
	assert.NotNil(t, client.ConnectedConnectionProvider)

	// check subscriptions
	assert.Equal(t, len(client.Subscriptions), 1)
	subscriptions := client.Subscriptions["agent.my-agent-id"]
	assert.Equal(t, len(subscriptions), 1)

	// test subscription callback
	subscription := client.Subscriptions["agent.my-agent-id"][0]
	subscription.Callback(&yagnats.Message{
		Subject: "agent.my-agent-id",
		Payload: `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`,
	})

	// request received
	assert.Equal(t, receivedRequest, Request{
		ReplyTo: "reply to me!",
		Method:  "ping",
		Args:    []string{"foo", "bar"},
	})

	// response sent
	assert.Equal(t, len(client.PublishedMessages), 1)
	messages := client.PublishedMessages["reply to me!"]

	assert.Equal(t, len(messages), 1)
	message := messages[0]

	assert.Equal(t, message.Payload, `{"value":"expected value"}`)
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
	s := settings.Settings{
		AgentId: "my-agent-id",
		Mbus:    "nats://foo:bar@127.0.0.1:1234",
	}

	client = fakeyagnats.New()
	handler = newNatsHandler(client, s)
	return
}
