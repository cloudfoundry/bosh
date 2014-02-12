package mbus_test

import (
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	. "bosh/mbus"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"encoding/json"
	"github.com/cloudfoundry/yagnats"
	"github.com/cloudfoundry/yagnats/fakeyagnats"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildNatsClientAndHandler(settings boshsettings.Service) (client *fakeyagnats.FakeYagnats, handler boshhandler.Handler) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	client = fakeyagnats.New()
	handler = NewNatsHandler(settings, logger, client)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("nats handler start", func() {
			settings := &fakesettings.FakeSettingsService{
				AgentId: "my-agent-id",
				MbusUrl: "nats://foo:bar@127.0.0.1:1234",
			}
			client, handler := buildNatsClientAndHandler(settings)

			var receivedRequest boshhandler.Request

			handler.Start(func(req boshhandler.Request) (resp boshhandler.Response) {
				receivedRequest = req
				return boshhandler.NewValueResponse("expected value")
			})
			defer handler.Stop()

			assert.NotNil(GinkgoT(), client.ConnectedConnectionProvider)

			assert.Equal(GinkgoT(), len(client.Subscriptions), 1)
			subscriptions := client.Subscriptions["agent.my-agent-id"]
			assert.Equal(GinkgoT(), len(subscriptions), 1)

			expectedPayload := []byte(`{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`)
			subscription := client.Subscriptions["agent.my-agent-id"][0]
			subscription.Callback(&yagnats.Message{
				Subject: "agent.my-agent-id",
				Payload: expectedPayload,
			})

			assert.Equal(GinkgoT(), receivedRequest, boshhandler.Request{
				ReplyTo: "reply to me!",
				Method:  "ping",
				Payload: expectedPayload,
			})

			assert.Equal(GinkgoT(), len(client.PublishedMessages), 1)
			messages := client.PublishedMessages["reply to me!"]

			assert.Equal(GinkgoT(), len(messages), 1)
			message := messages[0]

			assert.Equal(GinkgoT(), []byte(`{"value":"expected value"}`), message.Payload)
		})
		It("nats send periodic heartbeat", func() {

			settings := &fakesettings.FakeSettingsService{
				AgentId: "my-agent-id",
				MbusUrl: "nats://foo:bar@127.0.0.1:1234",
			}
			client, handler := buildNatsClientAndHandler(settings)

			errChan := make(chan error, 1)
			expectedHeartbeat := Heartbeat{Job: "foo", Index: 0}

			go func() {
				errChan <- handler.SendToHealthManager("heartbeat", expectedHeartbeat)
			}()

			var err error
			select {
			case err = <-errChan:
			}
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), len(client.PublishedMessages), 1)
			messages := client.PublishedMessages["hm.agent.heartbeat.my-agent-id"]

			assert.Equal(GinkgoT(), len(messages), 1)
			message := messages[0]

			expectedJson, _ := json.Marshal(expectedHeartbeat)
			assert.Equal(GinkgoT(), string(expectedJson), string(message.Payload))
		})
		It("nats handler connection info", func() {

			settings := &fakesettings.FakeSettingsService{MbusUrl: "nats://foo:bar@127.0.0.1:1234"}
			client, handler := buildNatsClientAndHandler(settings)

			err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
			assert.NoError(GinkgoT(), err)
			defer handler.Stop()

			assert.NotNil(GinkgoT(), client.ConnectedConnectionProvider)

			connInfo := client.ConnectedConnectionProvider

			expectedConnInfo := &yagnats.ConnectionInfo{
				Addr:     "127.0.0.1:1234",
				Username: "foo",
				Password: "bar",
			}

			assert.Equal(GinkgoT(), connInfo, expectedConnInfo)
		})
		It("nats handler connection info does not err when no username and password", func() {

			settings := &fakesettings.FakeSettingsService{MbusUrl: "nats://127.0.0.1:1234"}
			_, handler := buildNatsClientAndHandler(settings)

			err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
			assert.NoError(GinkgoT(), err)
			defer handler.Stop()
		})
		It("nats handler connection info errs when has username without password", func() {

			settings := &fakesettings.FakeSettingsService{MbusUrl: "nats://foo@127.0.0.1:1234"}
			_, handler := buildNatsClientAndHandler(settings)

			err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
			assert.Error(GinkgoT(), err)
			defer handler.Stop()
		})
	})
}
